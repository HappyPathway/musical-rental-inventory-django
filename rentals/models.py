from django.db import models
from django.conf import settings
from django.urls import reverse
from django.utils import timezone
from phonenumber_field.modelfields import PhoneNumberField
from simple_history.models import HistoricalRecords
from inventory.models import Equipment
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
import uuid

class Customer(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, null=True, blank=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    email = models.EmailField()
    phone = PhoneNumberField()
    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    zip_code = models.CharField(max_length=20)
    id_type = models.CharField(max_length=50, choices=[
        ('drivers_license', 'Driver\'s License'),
        ('passport', 'Passport'),
        ('state_id', 'State ID'),
        ('other', 'Other')
    ])
    id_number = models.CharField(max_length=100)
    id_image = models.ImageField(upload_to='customer_ids/', blank=True, null=True)
    notes = models.TextField(blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    history = HistoricalRecords()
    
    def __str__(self):
        return f"{self.first_name} {self.last_name}"
    
    def get_full_name(self):
        return f"{self.first_name} {self.last_name}"
    
    def get_absolute_url(self):
        return reverse('rentals:customer_detail', args=[str(self.id)])

# Signal to create Customer record when a User is created or updated
@receiver(post_save, sender=User)
def create_or_update_customer(sender, instance, created, **kwargs):
    """
    Create or update a Customer record when a User registers or is updated.
    This links the User auth system with the Rental customer records.
    """
    # Only proceed if the user has a profile and is a customer type
    if hasattr(instance, 'profile') and instance.profile.user_type == 'customer':
        # Check if a customer record already exists for this user
        customer, created = Customer.objects.get_or_create(
            user=instance,
            defaults={
                'first_name': instance.first_name,
                'last_name': instance.last_name,
                'email': instance.email,
                'phone': getattr(instance.profile, 'phone_number', ''),
                'address': getattr(instance.profile, 'address', ''),
                'city': getattr(instance.profile, 'city', ''),
                'state': getattr(instance.profile, 'state', ''),
                'zip_code': getattr(instance.profile, 'zip_code', ''),
                'id_type': 'drivers_license',  # Default value
                'id_number': f"USER{instance.id}",  # Default value
            }
        )
        
        # If customer exists but user info was updated, update the customer record too
        if not created:
            customer.first_name = instance.first_name
            customer.last_name = instance.last_name
            customer.email = instance.email
            if hasattr(instance, 'profile'):
                if hasattr(instance.profile, 'phone_number'):
                    customer.phone = instance.profile.phone_number
                customer.address = instance.profile.address
                customer.city = instance.profile.city
                customer.state = instance.profile.state
                customer.zip_code = instance.profile.zip_code
            customer.save()

class Rental(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('active', 'Active'),
        ('overdue', 'Overdue'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    )
    
    DURATION_TYPE_CHOICES = (
        ('daily', 'Daily'),
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
    )
    
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='rentals')
    equipment = models.ManyToManyField(Equipment, through='RentalItem')
    start_date = models.DateField()
    end_date = models.DateField()
    duration_type = models.CharField(max_length=10, choices=DURATION_TYPE_CHOICES, default='daily')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    deposit_total = models.DecimalField(max_digits=10, decimal_places=2)
    deposit_paid = models.BooleanField(default=False)
    notes = models.TextField(blank=True)
    contract_signed = models.BooleanField(default=False)
    contract_signed_date = models.DateTimeField(blank=True, null=True)
    contract_signature_data = models.TextField(blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    history = HistoricalRecords()
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Rental #{self.id} - {self.customer}"
    
    def get_absolute_url(self):
        return reverse('rentals:rental_detail', args=[str(self.id)])
    
    def is_active(self):
        return self.status == 'active'
    
    def is_overdue(self):
        print(f"Checking overdue: end_date={self.end_date}, today={timezone.now().date()}, status={self.status}")
        return self.end_date < timezone.now().date() and self.status == 'active'
    
    def mark_as_returned(self):
        for item in self.items.all():
            equipment = item.equipment
            equipment.status = 'available'
            equipment.save()
        
        self.status = 'completed'
        self.save()
    
    def calculate_total_price(self):
        total = sum(item.price * item.quantity for item in self.items.all())
        return total
    
    def calculate_deposit_total(self):
        total = sum(item.equipment.deposit_amount * item.quantity for item in self.items.all())
        return total
        
    @property
    def amount_paid(self):
        # Calculate the total amount paid through payments
        return sum(payment.amount for payment in self.payments.filter(status='completed'))
    
    @property
    def balance_due(self):
        # Calculate the remaining balance
        return self.total_price - self.amount_paid
    
    def clean(self):
        """Validate that end_date is not before start_date"""
        if self.end_date and self.start_date and self.end_date < self.start_date:
            from django.core.exceptions import ValidationError
            raise ValidationError("End date cannot be before start date")
    
    def save(self, *args, **kwargs):
        """Call clean() before saving"""
        self.full_clean()
        super().save(*args, **kwargs)

class RentalItem(models.Model):
    rental = models.ForeignKey(Rental, on_delete=models.CASCADE, related_name='items')
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    condition_note_checkout = models.TextField(blank=True)
    condition_note_return = models.TextField(blank=True)
    returned = models.BooleanField(default=False)
    returned_date = models.DateTimeField(blank=True, null=True)
    
    def __str__(self):
        return f"{self.quantity}x {self.equipment.name} for {self.rental}"
    
    def save(self, *args, **kwargs):
        # Update equipment status if this is a new rental item
        is_new = self.pk is None
        
        if is_new:
            self.equipment.status = 'rented'
            self.equipment.save()
        
        super().save(*args, **kwargs)

class Contract(models.Model):
    rental = models.OneToOneField(Rental, on_delete=models.CASCADE, related_name='contract')
    content = models.TextField()
    generated_on = models.DateTimeField(auto_now_add=True)
    file = models.FileField(upload_to='contracts/', blank=True, null=True)
    
    def __str__(self):
        return f"Contract for Rental #{self.rental.id}"
