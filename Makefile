.PHONY: venv install migrate run shell test clean superuser static collectstatic lint help kill reset test-selenium test-selenium-inventory test-selenium-rentals test-selenium-users test-selenium-payments infra import-fixtures docker-build docker-run docker-push gcp-auth deploy-cloud-run taint-sa-key fetch-pa-speakers load-pa-fixtures setup-pa-inventory test test-unit test-integration test-e2e test-e2e-visual test-e2e-inventory test-e2e-rentals test-e2e-users test-e2e-payments infra-apply fix-cloudbuild-sa-permissions test-cloudbuild tf-deploy tasks-init tasks-plan tasks-apply tasks-list import-resources import-common-resources

# Include environment variables if .env exists
-include .env

PYTHON = python3
PIP = pip3
MANAGE = python manage.py
VENV_NAME = venv
VENV_ACTIVATE = . $(VENV_NAME)/bin/activate
VENV_BIN = $(VENV_NAME)/bin

# GCP and Docker variables with defaults (override in .env)
GCP_PROJECT_ID ?= happypathway-1522441039906
GCP_REGION ?= us-central1
CONTAINER_REGISTRY ?= $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT_ID)/roknsound-images
IMAGE_NAME ?= roknsound-rental-inventory
IMAGE_TAG ?= latest
FULL_IMAGE_NAME = $(CONTAINER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

kill:
	@echo "Killing all Django server processes..."
	@ps auxw | grep runserver | grep -v grep | awk '{ print $$2 }' | xargs kill -9 2>/dev/null || echo "No Django server processes found."

help:
	@echo "========== ROKNSOUND MUSICAL RENTAL INVENTORY SYSTEM =========="
	@echo "Available commands:"
	@echo ""
	@echo "Development commands:"
	@echo "  make venv          - Create a virtual environment"
	@echo "  make install       - Install dependencies"
	@echo "  make migrate       - Apply migrations"
	@echo "  make makemigrations - Create new migrations (usage: make makemigrations app=myapp)"
	@echo "  make run           - Run development server"
	@echo "  make shell         - Open Django shell"
	@echo "  make superuser     - Create a superuser"
	@echo "  make static        - Collect static files"
	@echo "  make kill          - Kill all running Django server processes"
	@echo "  make reset         - Kill server, collect static files, and restart server"
	@echo "  make startapp      - Create a new Django app (usage: make startapp app=myapp)"
	@echo ""
	@echo "Testing commands:"
	@echo "  make test          - Run all Django tests (usage: make test app=myapp)"
	@echo "  make lint          - Run linting with flake8"
	@echo "  make clean         - Remove Python artifacts and cache files"
	@echo "  make test-selenium - Run all Selenium tests headlessly"
	@echo "  make test-selenium-inventory - Run inventory Selenium tests"
	@echo "  make test-selenium-rentals   - Run rentals Selenium tests"
	@echo "  make test-selenium-users     - Run users Selenium tests"
	@echo "  make test-selenium-payments  - Run payments Selenium tests"
	@echo "  make test-user-management-flow - Run user management flow tests"
	@echo "  make test-mobile   - Run mobile inventory tests"
	@echo "  make test-selenium-visual    - Run Selenium tests with visible browser"
	@echo "  make test-functional-auth    - Run authentication functional tests with visible browser"
	@echo "  make test-functional-equipment - Run equipment management functional tests with visible browser"
	@echo "  make test-functional-rentals - Run rental management functional tests with visible browser"
	@echo "  make test-functional-payments - Run payment processing functional tests with visible browser"
	@echo "  make test-functional-all     - Run all functional tests with visible browser"
	@echo ""
	@echo "Data management:"
	@echo "  make import-fixtures - Load fixture data (usage: make import-fixtures app=myapp)"
	@echo ""
	@echo "Docker commands:"
	@echo "  make docker-build  - Build the Docker image"
	@echo "  make docker-run    - Run the Docker container locally"
	@echo "  make docker-stop   - Stop and remove the running Docker container"
	@echo "  make docker-tag    - Tag Docker image for GCP Artifact Registry"
	@echo "  make docker-push   - Push Docker image to GCP Artifact Registry"
	@echo ""
	@echo "GCP deployment commands:"
	@echo "  make gcp-auth      - Authenticate with Google Cloud"
	@echo "  make deploy-cloud-run - Deploy to Cloud Run"
	@echo "  make deploy-all    - Build, push, and deploy to Cloud Run"
	@echo ""
	@echo "Infrastructure commands:"
	@echo "  make infra         - Apply Terraform infrastructure changes"
	@echo "  make taint-sa-key  - Taint the service account key for rotation"
	@echo "  make backend-state-init - Initialize Terraform backend state"
	@echo "  make backend-state-apply - Apply Terraform backend state configuration"
	@echo "  make infra-init    - Initialize main infrastructure Terraform"
	@echo "  make setup-backend - Set up Terraform backend in GCS"
	@echo "  make terratest     - Run Terratest infrastructure tests"
	@echo ""
	@echo "Note: Always use 'make reset' after making CSS or JavaScript changes"
	@echo "      to rebuild static files and restart the server."
	@echo "================================================================"

venv:
	$(PYTHON) -m venv $(VENV_NAME)
	@echo "Virtual environment created. Activate it with:"
	@echo "  source $(VENV_NAME)/bin/activate"

install: venv
	$(VENV_BIN)/pip install --upgrade pip
	$(VENV_BIN)/pip install -r requirements.txt

startproject:
	$(VENV_BIN)/django-admin startproject music_rental .

migrate:
	$(VENV_BIN)/$(MANAGE) migrate

makemigrations:
ifdef app
	$(VENV_BIN)/$(MANAGE) makemigrations $(app)
else
	$(VENV_BIN)/$(MANAGE) makemigrations
endif

startapp:
ifndef app
	@echo "Usage: make startapp app=myapp"
else
	$(VENV_BIN)/$(MANAGE) startapp $(app)
endif

run:
	$(VENV_BIN)/$(MANAGE) runserver 0.0.0.0:8000

shell:
	$(VENV_BIN)/$(MANAGE) shell

test: test-unit test-integration
	@echo "All tests complete (excluding E2E tests)"

test-quiet:
	@echo "Running tests (quiet mode)..."
	@$(VENV_ACTIVATE) && python -m pytest -q tests/

clean:
	@echo "Cleaning up temporary and unnecessary files..."
	@find . -type d -name "__pycache__" -exec rm -rf {} +
	@find . -type d -name "*.egg-info" -exec rm -rf {} +
	@find . -type d -name "*.egg" -exec rm -rf {} +
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name "*.pyo" -delete
	@find . -type f -name "*.pyd" -delete
	@find . -type f -name ".DS_Store" -delete
	@find . -type f -name "*.bak" -delete
	@find . -type f -name "*.swp" -delete
	@find . -type f -name "*.orig" -delete
	@rm test-screenshots/*.png
	@find . -type d -name ".cache" -exec rm -rf {} +
	@find . -type d -name ".pytest_cache" -exec rm -rf {} +
	@find . -type d -name ".coverage" -exec rm -rf {} +
	@find . -type d -name "htmlcov" -exec rm -rf {} +
	@rm -rf .coverage coverage.xml coverage_html_report/
	@echo "Clean completed!"

superuser:
	$(VENV_BIN)/$(MANAGE) createsuperuser

static:
	$(VENV_BIN)/$(MANAGE) collectstatic

lint:
	$(VENV_BIN)/flake8

reset: kill static run
	@echo "Reset complete: server restarted with updated static files."

# Selenium Test Targets
test-selenium:
	$(VENV_ACTIVATE) && ./run_selenium_tests.py --headless

test-selenium-inventory:
	$(VENV_ACTIVATE) && ./run_selenium_tests.py --headless tests.functional.test_inventory

test-selenium-rentals:
	$(VENV_ACTIVATE) && ./run_selenium_tests.py --headless tests.functional.test_rentals

test-selenium-users:
	$(VENV_ACTIVATE) && ./run_selenium_tests.py --headless tests.functional.test_users

test-selenium-payments:
	$(VENV_ACTIVATE) && ./run_selenium_tests.py --headless tests.functional.test_payments

test-user-management-flow:
	$(VENV_ACTIVATE) && ./run_selenium_tests.py --headless tests.functional.test_users.UserManagementFlowTestCase

# Mobile-specific test target
test-mobile:
	$(VENV_ACTIVATE) && ./run_mobile_inventory_tests.py

# Visual browser tests (non-headless)
test-selenium-visual:
	$(VENV_ACTIVATE) && ./run_selenium_tests.py

# Functional Tests with visible browser and pauses for human review
test-functional-auth:
	@echo "Running authentication functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/test_authentication.py -v

test-functional-equipment:
	@echo "Running equipment management functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/test_equipment.py -v

test-functional-rentals:
	@echo "Running rental management functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/test_rentals.py -v

test-functional-payments:
	@echo "Running payment processing functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/test_payments.py -v

test-functional-all:
	@echo "Running all functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/ -v

# Additional functional tests for specific features
test-functional-profile:
	@echo "Running profile management functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/test_profile.py -v

test-functional-responsive:
	@echo "Running responsive design functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/test_responsive.py -v

test-functional-equipment-edit:
	@echo "Running equipment editing functional tests with visible browser..."
	$(VENV_ACTIVATE) && python -m pytest tests/functional/test_equipment_edit.py -v

# Terraform Infrastructure Target

infra-init:
	@echo "Initializing main infrastructure Terraform with GCS backend..."
	@echo "Ensure the bucket name in infra/backend.tf matches the one created."
	cd infra && terraform init -migrate-state -upgrade
	@echo "Main infrastructure backend initialized."

infra-apply:
	@echo "Applying main infrastructure Terraform configuration..."
	cd infra && terraform apply -auto-approve
	@echo "Main infrastructure applied successfully."

infra:
	@echo "Applying Terraform infrastructure changes..."
	cd infra && \
	terraform init && \
	terraform validate && \
	terraform plan && \
	terraform apply -auto-approve
	@echo "Terraform apply complete."

# Terraform Infrastructure Target
infra-destroy:
	@echo "Applying Terraform infrastructure changes..."
	cd infra && \
	terraform init && \
	terraform validate && \
	terraform plan && \
	terraform destroy -auto-approve
	@echo "Terraform destroy complete."

# Import fixtures
import-fixtures:
ifdef app
	$(VENV_BIN)/$(MANAGE) loaddata $(app)
else
	@echo "Loading fixtures for all apps..."
	$(VENV_BIN)/$(MANAGE) loaddata inventory/fixtures/*.json
	$(VENV_BIN)/$(MANAGE) loaddata users/fixtures/*.json
	$(VENV_BIN)/$(MANAGE) loaddata rentals/fixtures/*.json
	$(VENV_BIN)/$(MANAGE) loaddata payments/fixtures/*.json
endif

# Docker Targets
docker-build:
	@echo "Building Docker image for ROKNSOUND rental inventory..."
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "Docker image built successfully."

docker-run:
	@echo "Attempting to stop and remove existing container using port 8080..."
	@CONTAINER_ID=$$(docker ps -q --filter "publish=8080"); \
	if [ -n "$$CONTAINER_ID" ]; then \
		echo "Stopping container $$CONTAINER_ID..."; \
		docker stop $$CONTAINER_ID; \
		echo "Removing container $$CONTAINER_ID..."; \
		docker rm $$CONTAINER_ID; \
	else \
		echo "No running container found using port 8080."; \
	fi
	@echo "Killing any remaining process on port 8080..."
	@PID=$$(lsof -ti tcp:8080); \
	if [ -n "$$PID" ]; then \
		echo "Killing process $$PID on port 8080..."; \
		kill -9 $$PID 2>/dev/null || true; \
		sleep 1; \
	else \
		echo "No process found on port 8080."; \
	fi
	@echo "Running Docker container locally with GCP service account..."
	docker run -p 8080:8080 \
		-e DEBUG=1 \
		-e SECRET_KEY=localtesting \
		-e GS_BUCKET_NAME=roknsound-music-rental-inventory \
		-e GS_PROJECT_ID=happypathway-1522441039906 \
		-v $$(pwd)/gcp-service-account-key.json:/app/gcp-service-account-key.json \
		-e GOOGLE_APPLICATION_CREDENTIALS=/app/gcp-service-account-key.json \
		$(IMAGE_NAME):$(IMAGE_TAG)

docker-stop:
	@echo "Attempting to stop and remove existing container using port 8080..."
	@CONTAINER_ID=$$(docker ps -q --filter "publish=8080"); \
	if [ -n "$$CONTAINER_ID" ]; then \
		echo "Stopping container $$CONTAINER_ID..."; \
		docker stop $$CONTAINER_ID; \
		echo "Removing container $$CONTAINER_ID..."; \
		docker rm $$CONTAINER_ID; \
	else \
		echo "No running container found using port 8080."; \
	fi
	
docker-tag:
	@echo "Tagging Docker image for GCP Artifact Registry..."
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(FULL_IMAGE_NAME)

docker-push: create-ar-repo docker-tag
	@echo "Pushing Docker image to GCP Artifact Registry..."
	@echo "Authenticating with Google Container Registry..."
	gcloud auth configure-docker $(GCP_REGION)-docker.pkg.dev --quiet
	docker push $(FULL_IMAGE_NAME)


# GCP Auth and Deployment Targets
gcp-auth:
	@echo "Authenticating with Google Cloud..."
	gcloud auth login
	gcloud config set project $(GCP_PROJECT_ID)
	gcloud auth configure-docker $(GCP_REGION)-docker.pkg.dev

create-ar-repo:
	@echo "Creating Google Artifact Registry repository if it doesn't exist..."
	gcloud artifacts repositories describe roknsound-images \
		--project=$(GCP_PROJECT_ID) \
		--location=$(GCP_REGION) \
		|| gcloud artifacts repositories create roknsound-images \
		--project=$(GCP_PROJECT_ID) \
		--location=$(GCP_REGION) \
		--repository-format=docker \
		--description="Docker repository for ROKNSOUND images"
	@echo "Repository roknsound-images is ready."

# Django database migration targets
django-migrate-prod:
	@echo "Running migrations on production database..."
	@echo "Building temporary migration image..."
	docker build -t $(IMAGE_NAME):migrate --build-arg="MIGRATIONS_ONLY=1" .
	@echo "Running migrations against production database..."
	gcloud run jobs create roknsound-migrations \
		--image=$(CONTAINER_REGISTRY)/$(IMAGE_NAME):migrate \
		--region=$(GCP_REGION) \
		--service-account=roknsound-storage-sa@$(GCP_PROJECT_ID).iam.gserviceaccount.com \
		--set-env-vars="DJANGO_SECRET_KEY=$(shell terraform output -state=infra/terraform.tfstate -raw django_secret_key 2>/dev/null || echo 'dummy-key'),DATABASE_URL=$(shell terraform output -state=infra/terraform.tfstate -raw database_url 2>/dev/null || echo 'dummy-url'),GS_BUCKET_NAME=$(GS_BUCKET_NAME),DEBUG=0,MIGRATE_ONLY=1" \
		--task-timeout=10m \
		--max-retries=2 \
		--execute-now \
		|| echo "Migration job already exists"
	gcloud run jobs execute roknsound-migrations --region=$(GCP_REGION)

# Update deploy-cloud-run to include migrations
deploy-cloud-run: docker-push django-migrate-prod
	@echo "Deploying to Cloud Run..."
	gcloud run deploy roknsound-rental-inventory \
		--image=$(FULL_IMAGE_NAME) \
		--region=$(GCP_REGION) \
		--platform=managed \
		--allow-unauthenticated \
		--service-account=roknsound-storage-sa@$(GCP_PROJECT_ID).iam.gserviceaccount.com \
		--set-env-vars=GS_BUCKET_NAME=$(GS_BUCKET_NAME),DEBUG=0

# Deploy everything (build, push, and deploy to Cloud Run)
deploy-all: docker-build docker-push deploy-cloud-run
	@echo "Full deployment completed successfully!"

# Terraform Backend State Management Targets
.PHONY: backend-state-init backend-state-apply infra-init setup-backend

backend-state-init:
	@echo "Initializing Terraform for backend state management..."
	cd backend-state && terraform init

backend-state-apply:
	@echo "Applying Terraform configuration to create the state bucket..."
	cd backend-state && terraform apply -auto-approve
	@echo "Terraform state bucket setup complete."
	
setup-backend: backend-state-init backend-state-apply infra-init
	@echo "Terraform backend setup complete. State is now managed in GCS."

# Taint the service account key to force its recreation
taint-sa-key:
	@echo "Tainting Google service account key..."
	cd infra && terraform init && terraform taint google_service_account_key.app_service_account_key
	@echo "Service account key tainted. Run 'make infra' to apply changes and generate a new key."

# Test targets
.PHONY: test test-unit test-integration test-e2e test-all

test-unit:
	@echo "Running unit tests..."
	@/bin/bash -c 'source venv/bin/activate && python -m pytest tests/unit/'

test-integration:
	@echo "Running integration tests..."
	@. $(VENV_ACTIVATE) && PYTHONPATH=. pytest -q tests/integration/

test-e2e:
	@echo "Running end-to-end tests..."
	@. $(VENV_ACTIVATE) && PYTHONPATH=. pytest tests/e2e/ --tb=short

test-e2e-visual:
	@echo "Running end-to-end tests with browser visible..."
	@. $(VENV_ACTIVATE) && PYTHONPATH=. pytest tests/e2e/ --no-headless

test-e2e-inventory:
	@echo "Running inventory E2E tests..."
	@. $(VENV_ACTIVATE) && PYTHONPATH=. pytest tests/e2e/test_inventory.py

test-e2e-rentals:
	@echo "Running rentals E2E tests..."
	@. $(VENV_ACTIVATE) && PYTHONPATH=. pytest tests/e2e/test_rentals.py

test-e2e-users:
	@echo "Running user management E2E tests..."
	@. $(VENV_ACTIVATE) && PYTHONPATH=. pytest tests/e2e/test_users.py

test-e2e-payments:
	@echo "Running payment system E2E tests..."
	@. $(VENV_ACTIVATE) && PYTHONPATH=. pytest tests/e2e/test_payments.py

test-all: test-unit test-integration test-e2e
	@echo "All tests complete (including E2E tests)"


# Execute migrations on the deployed database
run-migrations:
	@echo "Running migrations on the deployed database..."
	source venv/bin/activate && \
	cd infra && \
	export MIGRATION_JOB=$$(terraform output -raw cloud_run_url | cut -d'/' -f3 | cut -d'.' -f1)-migrations && \
	gcloud run jobs execute $$MIGRATION_JOB --region=$$(terraform output -raw cloud_run_url | cut -d'/' -f3 | cut -d'.' -f2 | cut -d'-' -f1)
	@echo "Migrations completed successfully!"

# Full deployment (Terraform + migrations)
deploy-full: infra run-migrations
	@echo "Full deployment completed successfully!"
	@echo "Your application is available at: $$(cd infra && terraform output -raw cloud_run_url)"

# Task management targets
.PHONY: tasks-init tasks-plan tasks-apply tasks-list

# Initialize tasks Terraform
tasks-init:
	@echo "Initializing task management infrastructure..."
	source venv/bin/activate && cd tasks && terraform init

# Plan task changes
tasks-plan:
	@echo "Planning task management changes..."
	source venv/bin/activate && cd tasks && terraform plan

# Apply task changes
tasks-apply:
	@echo "Applying task management changes..."
	source venv/bin/activate && cd tasks && terraform apply -auto-approve
	@echo "Tasks have been managed successfully!"

# List all current tasks/issues
tasks-list:
	@echo "Listing current tasks from GitHub..."
	source venv/bin/activate && cd tasks && \
	  terraform output -json github_issues | jq -r '.[] | "- #\(.number): \(.title) (\(.state))"'

# Import common resources that might already exist in GCP
import-common-resources:
	@echo "Importing common GCP resources that frequently need importing..."
	source venv/bin/activate && cd infra && terraform init
	@echo "Trying to import service account..."
	cd infra && terraform import google_service_account.app_service_account projects/$(GCP_PROJECT_ID)/serviceAccounts/roknsound-storage-sa@$(GCP_PROJECT_ID).iam.gserviceaccount.com || echo "Service account import failed or already exists in state"
	@echo "Trying to import storage bucket..."
	cd infra && terraform import google_storage_bucket.media_bucket roknsound-music-rental-inventory || echo "Storage bucket import failed or already exists in state"
	@echo "Import process completed."

# Run Terratest infrastructure tests
terratest:
	@echo "Running Terratest infrastructure tests..."
	source venv/bin/activate && cd infra/test && go test -v
	@echo "Terratest infrastructure validation complete."