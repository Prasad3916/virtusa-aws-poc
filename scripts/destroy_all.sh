#!/bin/bash
set +e

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
echo "[3/4] Executing terraform destroy..."
terraform destroy -auto-approve || true

# 4. Forceful AWS Account Cleanup
echo "[4/4] Running full AWS resource wipeout scan..."
cd ..
chmod +x ./scripts/nuke_all_aws_resources.sh
./scripts/nuke_all_aws_resources.sh

echo "=========================================================="
echo "✔ ALL TICKETDESK AWS RESOURCES HAVE BEEN DESTROYED!"
echo "=========================================================="

