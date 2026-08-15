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

# 0. Clean up detached Internet Gateways to prevent InternetGatewayLimitExceeded
echo "Checking and cleaning detached Internet Gateways..."
DETACHED_IGWS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.state,Values=detached" --region us-east-1 --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo "")
for igw in $DETACHED_IGWS; do
  if [ -n "$igw" ] && [ "$igw" != "None" ]; then
    echo "Deleting detached Internet Gateway: $igw"
    aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region us-east-1 >/dev/null 2>&1 || true
  fi
done

# 6. SSM Parameters
if aws ssm get-parameter --name "/ticketdesk/DB_HOST" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_ssm_parameter.db_host "/ticketdesk/DB_HOST" || true
fi

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

# 10. Target Group Validation & Import
TG_VPC=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region us-east-1 --query "TargetGroups[0].VpcId" --output text 2>/dev/null || echo "")
if [ -n "$TG_VPC" ] && [ "$TG_VPC" != "None" ]; then
  VPC_EXISTS=$(aws ec2 describe-vpcs --vpc-ids "$TG_VPC" --region us-east-1 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
  if [ -z "$VPC_EXISTS" ] || [ "$VPC_EXISTS" = "None" ]; then
    echo "Cleaning broken Target Group referencing deleted VPC ($TG_VPC)..."
    TG_ARN=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region us-east-1 --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region us-east-1 >/dev/null 2>&1 || true
  else
    TG_ARN=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region us-east-1 --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
    terraform import aws_lb_target_group.api "$TG_ARN" || true
  fi
fi

# 11. DB Subnet Group Validation & Import
if aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region us-east-1 >/dev/null 2>&1; then
  DB_VPC=$(aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region us-east-1 --query "DBSubnetGroups[0].VpcId" --output text 2>/dev/null || echo "")
  VPC_EXISTS=$(aws ec2 describe-vpcs --vpc-ids "$DB_VPC" --region us-east-1 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
  if [ -z "$VPC_EXISTS" ] || [ "$VPC_EXISTS" = "None" ]; then
    echo "Cleaning broken DB Subnet Group referencing deleted VPC ($DB_VPC)..."
    aws rds delete-db-subnet-group --db-subnet-group-name "ticketdesk-db-subnet-group" --region us-east-1 >/dev/null 2>&1 || true
  else
    terraform import aws_db_subnet_group.main "ticketdesk-db-subnet-group" || true
  fi
fi

# 12. Lambda Permission
if [ -n "$ACCOUNT_ID" ]; then
  echo "Importing existing Lambda Permission..."
  terraform import aws_lambda_permission.allow_s3_invoke "TicketDesk-thumbnail-generator/AllowS3InvokeThumbnailGenerator-$ACCOUNT_ID" || true
fi

# 13. Load Balancer Validation & Import
ALB_VPC=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region us-east-1 --query "LoadBalancers[0].VpcId" --output text 2>/dev/null || echo "")
if [ -n "$ALB_VPC" ] && [ "$ALB_VPC" != "None" ]; then
  VPC_EXISTS=$(aws ec2 describe-vpcs --vpc-ids "$ALB_VPC" --region us-east-1 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
  if [ -z "$VPC_EXISTS" ] || [ "$VPC_EXISTS" = "None" ]; then
    echo "Cleaning broken Load Balancer referencing deleted VPC ($ALB_VPC)..."
    ALB_ARN=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region us-east-1 --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region us-east-1 >/dev/null 2>&1 || true
    sleep 5
  else
    ALB_ARN=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region us-east-1 --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")
    terraform import aws_lb.main "$ALB_ARN" || true
  fi
fi


echo "Import check complete. Proceeding with clean deployment..."

