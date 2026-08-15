#!/bin/bash
set -e

echo "Checking and importing pre-existing global AWS resources into Terraform state..."

cd terraform

echo "Initializing Terraform providers..."
rm -f .terraform.lock.hcl
terraform init -upgrade

# 1. ECR Repository
if aws ecr describe-repositories --repository-names ticketdesk-api --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing ECR repository ticketdesk-api..."
  terraform import aws_ecr_repository.api ticketdesk-api || true
fi

# 2. CloudWatch Log Group
if aws logs describe-log-groups --log-group-name-prefix "/ecs/TicketDesk-logs" --region us-east-1 | grep "/ecs/TicketDesk-logs" >/dev/null 2>&1; then
  echo "Importing existing CloudWatch log group..."
  terraform import aws_cloudwatch_log_group.ecs_logs "/ecs/TicketDesk-logs" || true
fi

# 3. IAM Roles
if aws iam get-role --role-name "TicketDesk-ecs-execution-role" >/dev/null 2>&1; then
  terraform import aws_iam_role.ecs_execution_role "TicketDesk-ecs-execution-role" || true
fi

if aws iam get-role --role-name "TicketDesk-ecs-task-role" >/dev/null 2>&1; then
  terraform import aws_iam_role.ecs_task_role "TicketDesk-ecs-task-role" || true
fi

if aws iam get-role --role-name "TicketDesk-lambda-role" >/dev/null 2>&1; then
  terraform import aws_iam_role.lambda_role "TicketDesk-lambda-role" || true
fi

# 4. IAM Policies
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -n "$ACCOUNT_ID" ]; then
  terraform import aws_iam_policy.ecs_task_s3 "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-ecs-task-s3-policy" || true
  terraform import aws_iam_policy.lambda_policy "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-lambda-policy" || true
fi

# 5. Secrets Manager
if aws secretsmanager describe-secret --secret-id "TicketDesk-db-credentials" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_secretsmanager_secret.db_credentials "TicketDesk-db-credentials" || true
fi

# 6. SSM Parameters
if aws ssm get-parameter --name "/ticketdesk/DB_NAME" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_ssm_parameter.db_name "/ticketdesk/DB_NAME" || true
fi

if aws ssm get-parameter --name "/ticketdesk/S3_BUCKET" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_ssm_parameter.s3_bucket "/ticketdesk/S3_BUCKET" || true
fi

# 7. SNS Topic
if [ -n "$ACCOUNT_ID" ]; then
  terraform import aws_sns_topic.alarms "arn:aws:sns:us-east-1:$ACCOUNT_ID:TicketDesk-alarms-topic" || true
fi

# 8. Lambda Function
if aws lambda get-function --function-name "TicketDesk-thumbnail-generator" --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing Lambda function TicketDesk-thumbnail-generator..."
  terraform import aws_lambda_function.thumbnail_generator "TicketDesk-thumbnail-generator" || true
fi

# 9. S3 Buckets
if [ -n "$ACCOUNT_ID" ]; then
  if aws s3api head-bucket --bucket "ticketdesk-frontend-$ACCOUNT_ID" >/dev/null 2>&1; then
    terraform import aws_s3_bucket.frontend "ticketdesk-frontend-$ACCOUNT_ID" || true
  fi
  if aws s3api head-bucket --bucket "ticketdesk-attachments-$ACCOUNT_ID" >/dev/null 2>&1; then
    terraform import aws_s3_bucket.attachments "ticketdesk-attachments-$ACCOUNT_ID" || true
  fi
fi

echo "Import check complete. Proceeding with clean deployment..."
