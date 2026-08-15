#!/bin/bash
set +e

echo "Checking and importing pre-existing global AWS resources into Terraform state..."

cd terraform

echo "Initializing Terraform providers..."
rm -f .terraform.lock.hcl
terraform init -upgrade

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

# 1. VPC & Core Networking
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=TicketDesk-vpc" --region us-east-1 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  echo "Importing existing TicketDesk VPC ($VPC_ID)..."
  terraform import aws_vpc.main "$VPC_ID" || true
fi

IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=TicketDesk-igw" --region us-east-1 --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")
if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
  echo "Importing existing Internet Gateway ($IGW_ID)..."
  terraform import aws_internet_gateway.igw "$IGW_ID" || true
fi

SUB_PUB_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=TicketDesk-public-subnet-1" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
if [ -n "$SUB_PUB_1" ] && [ "$SUB_PUB_1" != "None" ]; then
  terraform import 'aws_subnet.public[0]' "$SUB_PUB_1" || true
fi

SUB_PUB_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=TicketDesk-public-subnet-2" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
if [ -n "$SUB_PUB_2" ] && [ "$SUB_PUB_2" != "None" ]; then
  terraform import 'aws_subnet.public[1]' "$SUB_PUB_2" || true
fi

SUB_PRIV_1=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=TicketDesk-private-subnet-1" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
if [ -n "$SUB_PRIV_1" ] && [ "$SUB_PRIV_1" != "None" ]; then
  terraform import 'aws_subnet.private[0]' "$SUB_PRIV_1" || true
fi

SUB_PRIV_2=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=TicketDesk-private-subnet-2" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
if [ -n "$SUB_PRIV_2" ] && [ "$SUB_PRIV_2" != "None" ]; then
  terraform import 'aws_subnet.private[1]' "$SUB_PRIV_2" || true
fi

# 2. Security Groups
SG_ALB=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=TicketDesk-alb-sg" --region us-east-1 --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ -n "$SG_ALB" ] && [ "$SG_ALB" != "None" ]; then
  terraform import aws_security_group.alb "$SG_ALB" || true
fi

SG_ECS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=TicketDesk-ecs-task-sg" --region us-east-1 --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ -n "$SG_ECS" ] && [ "$SG_ECS" != "None" ]; then
  terraform import aws_security_group.ecs_task "$SG_ECS" || true
fi

SG_RDS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=TicketDesk-rds-sg" --region us-east-1 --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ -n "$SG_RDS" ] && [ "$SG_RDS" != "None" ]; then
  terraform import aws_security_group.rds "$SG_RDS" || true
fi

# 3. Load Balancer & Target Group
ALB_ARN=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region us-east-1 --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  echo "Importing existing Load Balancer ticketdesk-alb..."
  terraform import aws_lb.main "$ALB_ARN" || true
fi

TG_ARN=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region us-east-1 --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  echo "Importing existing Target Group ticketdesk-tg..."
  terraform import aws_lb_target_group.api "$TG_ARN" || true
fi

# 4. Database Resources
if aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing DB Subnet Group ticketdesk-db-subnet-group..."
  terraform import aws_db_subnet_group.main "ticketdesk-db-subnet-group" || true
fi

if aws rds describe-db-instances --db-instance-identifier "ticketdesk-mysql-db" --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing RDS Instance ticketdesk-mysql-db..."
  terraform import aws_db_instance.main "ticketdesk-mysql-db" || true
fi

# 5. ECS & ECR
if aws ecs describe-clusters --clusters "TicketDesk-cluster" --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing ECS Cluster TicketDesk-cluster..."
  terraform import aws_ecs_cluster.main "TicketDesk-cluster" || true
fi

if aws ecr describe-repositories --repository-names ticketdesk-api --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing ECR repository ticketdesk-api..."
  terraform import aws_ecr_repository.api ticketdesk-api || true
fi

# 6. IAM Roles & Policies
if aws iam get-role --role-name "TicketDesk-ecs-execution-role" >/dev/null 2>&1; then
  terraform import aws_iam_role.ecs_execution_role "TicketDesk-ecs-execution-role" || true
fi

if aws iam get-role --role-name "TicketDesk-ecs-task-role" >/dev/null 2>&1; then
  terraform import aws_iam_role.ecs_task_role "TicketDesk-ecs-task-role" || true
fi

if aws iam get-role --role-name "TicketDesk-lambda-role" >/dev/null 2>&1; then
  terraform import aws_iam_role.lambda_role "TicketDesk-lambda-role" || true
fi

if [ -n "$ACCOUNT_ID" ]; then
  terraform import aws_iam_policy.ecs_task_s3 "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-ecs-task-s3-policy" || true
  terraform import aws_iam_policy.lambda_policy "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-lambda-policy" || true
  terraform import aws_iam_policy.ecs_execution_secrets "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-ecs-execution-secrets-policy" || true
fi

# 7. Secrets & SSM Parameters
if aws secretsmanager describe-secret --secret-id "TicketDesk-db-credentials" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_secretsmanager_secret.db_credentials "TicketDesk-db-credentials" || true
fi

if aws ssm get-parameter --name "/ticketdesk/DB_HOST" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_ssm_parameter.db_host "/ticketdesk/DB_HOST" || true
fi

if aws ssm get-parameter --name "/ticketdesk/DB_NAME" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_ssm_parameter.db_name "/ticketdesk/DB_NAME" || true
fi

if aws ssm get-parameter --name "/ticketdesk/S3_BUCKET" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_ssm_parameter.s3_bucket "/ticketdesk/S3_BUCKET" || true
fi

# 8. SNS Topic, Lambda & S3 Buckets
if [ -n "$ACCOUNT_ID" ]; then
  terraform import aws_sns_topic.alarms "arn:aws:sns:us-east-1:$ACCOUNT_ID:TicketDesk-alarms-topic" || true
fi

if aws lambda get-function --function-name "TicketDesk-thumbnail-generator" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_lambda_function.thumbnail_generator "TicketDesk-thumbnail-generator" || true
fi

if [ -n "$ACCOUNT_ID" ]; then
  if aws s3api head-bucket --bucket "ticketdesk-frontend-$ACCOUNT_ID" >/dev/null 2>&1; then
    terraform import aws_s3_bucket.frontend "ticketdesk-frontend-$ACCOUNT_ID" || true
  fi
  if aws s3api head-bucket --bucket "ticketdesk-attachments-$ACCOUNT_ID" >/dev/null 2>&1; then
    terraform import aws_s3_bucket.attachments "ticketdesk-attachments-$ACCOUNT_ID" || true
  fi
fi

echo "State reconciliation and import complete. Proceeding with clean terraform apply..."
