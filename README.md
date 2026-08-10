# Project TicketDesk - AWS Deployment Guide & Runbook

Welcome to **TicketDesk**! This runbook provides step-by-step instructions to deploy, monitor, and teardown the full TicketDesk stack on AWS using Terraform Infrastructure as Code, ECS Fargate, RDS MySQL, CloudFront + S3, Lambda, GitHub Actions, and CloudWatch.

---

## 🏗️ Architecture Overview

```
┌──────────────────┐
│     Browser      │ ──────► CloudFront + S3 (Static Frontend)
└────────┬─────────┘
         │ /api/*
┌────────▼─────────┐
│ Application Load │ (Public Subnets, Port 80)
│     Balancer     │
└────────┬─────────┘
         │
┌────────▼─────────┐
│   ECS Fargate    │ (Private Subnets, Port 8080)
│  (ticketdesk-api)│
└───┬──────────┬───┘
    │          │
┌───▼──────┐ ┌─▼──────────────┐
│ RDS MySQL│ │S3 Attachments  │ ──(ObjectCreated)──► Lambda Thumbnail
│(Private) │ │   Bucket       │                      Generator
└──────────┘ └────────────────┘
```

---

## 📋 Prerequisites

1. **AWS CLI v2** configured with credentials (`aws configure`).
2. **Terraform** (v1.5.0 or newer).
3. **Docker Desktop** running locally.
4. **Git** and a GitHub repository for CI/CD integration.

---

## 🚀 Step-by-Step Deployment (Zero to Hero)

### Step 1: Clone Repository & Build Container Locally
```bash
# Clone the repository
git clone https://github.com/Prasad3916/virtusa-aws-poc.git
cd cloud-poc/ticketapplication/backend/ticket-service

# Build and verify local Docker container (Non-root user test)
docker build -t ticketdesk-api:local .
docker run --rm ticketdesk-api:local whoami
# Expected output: appuser
```

---

### Step 2: Initialize & Apply Terraform Infrastructure
```bash
cd ../../../terraform

# Initialize Terraform plugins
terraform init

# Validate HCL configuration
terraform validate

# Provision all AWS resources (VPC, ALB, ECS, RDS, S3, CloudFront, Lambda, CloudWatch)
terraform apply -auto-approve
```

---

### Step 3: Push Initial Container Image to AWS ECR
```bash
# Obtain ECR Repository URL from Terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)
AWS_REGION="us-east-1"

# Log in to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL

# Tag with Git Commit SHA and Push
GIT_SHA=$(git rev-parse --short HEAD)
docker tag ticketdesk-api:local $ECR_URL:$GIT_SHA
docker tag ticketdesk-api:local $ECR_URL:latest

docker push $ECR_URL:$GIT_SHA
docker push $ECR_URL:latest

# Trigger ECS Service deployment
aws ecs update-service --cluster TicketDesk-cluster --service TicketDesk-service --force-new-deployment
```

---

### Step 4: Deploy Static Frontend to S3
```bash
cd ../ticketapplication/frontend
npm ci
npm run build

S3_FRONTEND_BUCKET=$(cd ../../terraform && terraform output -raw s3_frontend_bucket)
aws s3 sync dist/ s3://$S3_FRONTEND_BUCKET/ --delete
```

---

## 🧪 Post-Deployment Verification & Smoke Tests

Run the automated smoke test and 20-concurrent user load test script:
```bash
cd ../..
CLOUDFRONT_URL=$(cd terraform && terraform output -raw cloudfront_domain_name)
export TARGET_URL="http://$CLOUDFRONT_URL"

chmod +x ./scripts/smoke_test.sh
./scripts/smoke_test.sh
```

---

## 📊 Observability & Alarms

1. **CloudWatch Dashboard**: Open CloudWatch Console -> Dashboards -> `TicketDesk-Dashboard` to monitor Request Count, Latency, ECS CPU/Memory, and RDS DB Connections.
2. **CloudWatch Log Group**: `/ecs/TicketDesk-logs` (14-day retention).
3. **Alarms**:
   - `TicketDesk-ALB-5xx-Errors`: Triggers if ALB 5xx count > 5 in 1 minute.
   - `TicketDesk-Unhealthy-Targets`: Triggers if target host count < 1.
   - `TicketDesk-RDS-High-CPU`: Triggers if RDS CPU > 80%.

---

## 🧹 Stack Teardown (Clean Rebuild Proof)

To destroy the entire infrastructure and leave zero billable resources behind:
```bash
cd terraform
terraform destroy -auto-approve
```

---

## ✅ Deployment Readiness Checklist Verification (34 Items)

All 34 items on the Deployment Readiness Checklist are fully satisfied by this repository layout:
- **Container**: Multi-stage, non-root user `appuser`, git commit SHA tag, ECR image scanning enabled.
- **IaC**: 100% Terraform managed, remote backend ready, zero hardcoded secrets, clean destroy/rebuildable.
- **Network & DB**: Private subnets for ECS & RDS, ALB in public subnets, strict SGs, encrypted RDS MySQL with 7-day backups.
- **Frontend & Serverless**: CloudFront + S3 (OAC, non-public S3), direct S3 presigned URL uploads, Lambda thumbnail generator.
- **Pipeline & Operations**: GitHub Actions CI/CD with secret scanning & smoke tests, CloudWatch 14-day logs, dashboard, and 3 alarms.
