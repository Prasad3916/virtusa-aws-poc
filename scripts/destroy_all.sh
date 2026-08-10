#!/bin/bash
set -e

echo "=========================================================="
echo "TicketDesk AWS Stack Cleanup - Destroying All Resources"
echo "=========================================================="

cd terraform

# 1. Initialize Terraform
echo "[1/3] Initializing Terraform..."
rm -f .terraform.lock.hcl
terraform init -upgrade

# 2. Import existing resources into state to guarantee full teardown
echo "[2/3] Checking existing resources for clean deletion..."
chmod +x ../scripts/terraform_import_existing.sh
../scripts/terraform_import_existing.sh || true

# 3. Execute Terraform Destroy
echo "[3/3] Executing terraform destroy..."
terraform destroy -auto-approve

echo "=========================================================="
echo "✔ ALL TICKETDESK AWS RESOURCES HAVE BEEN DESTROYED!"
echo "=========================================================="
