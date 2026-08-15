#!/bin/bash
set +e

echo "Reconciling and importing pre-existing TicketDesk AWS resources into Terraform state..."

cd terraform

echo "Initializing Terraform providers..."
rm -f .terraform.lock.hcl
terraform init -upgrade

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

# 0. Discover Authoritative VPC ID containing RDS (Preserving existing RDS database)
RDS_VPC_ID=$(aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region us-east-1 --query "DBSubnetGroups[0].VpcId" --output text 2>/dev/null || echo "")
if [ -n "$RDS_VPC_ID" ] && [ "$RDS_VPC_ID" != "None" ]; then
  if aws ec2 describe-vpcs --vpc-ids "$RDS_VPC_ID" --region us-east-1 >/dev/null 2>&1; then
    VPC_ID="$RDS_VPC_ID"
    echo "Found Authoritative RDS VPC: $VPC_ID"
  fi
fi

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  CANDIDATE_VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=TicketDesk" --region us-east-1 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
  if [ -n "$CANDIDATE_VPC" ] && [ "$CANDIDATE_VPC" != "None" ]; then
    if aws ec2 describe-vpcs --vpc-ids "$CANDIDATE_VPC" --region us-east-1 >/dev/null 2>&1; then
      VPC_ID="$CANDIDATE_VPC"
    fi
  fi
fi

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
  CANDIDATE_VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=TicketDesk-vpc" --region us-east-1 --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
  if [ -n "$CANDIDATE_VPC" ] && [ "$CANDIDATE_VPC" != "None" ]; then
    if aws ec2 describe-vpcs --vpc-ids "$CANDIDATE_VPC" --region us-east-1 >/dev/null 2>&1; then
      VPC_ID="$CANDIDATE_VPC"
    fi
  fi
fi

# 1. VPC & Networking Resources
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  if aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region us-east-1 >/dev/null 2>&1; then
    echo "Importing verified existing TicketDesk VPC ($VPC_ID)..."
    terraform import aws_vpc.main "$VPC_ID" || true

    # Import Subnets within this Authoritative VPC
    SUB_PUB_1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=TicketDesk-public-subnet-1" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
    if [ -n "$SUB_PUB_1" ] && [ "$SUB_PUB_1" != "None" ]; then
      if aws ec2 describe-subnets --subnet-ids "$SUB_PUB_1" --region us-east-1 >/dev/null 2>&1; then
        terraform import 'aws_subnet.public[0]' "$SUB_PUB_1" || true
      fi
    fi

    SUB_PUB_2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=TicketDesk-public-subnet-2" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
    if [ -n "$SUB_PUB_2" ] && [ "$SUB_PUB_2" != "None" ]; then
      if aws ec2 describe-subnets --subnet-ids "$SUB_PUB_2" --region us-east-1 >/dev/null 2>&1; then
        terraform import 'aws_subnet.public[1]' "$SUB_PUB_2" || true
      fi
    fi

    SUB_PRIV_1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=TicketDesk-private-subnet-1" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
    if [ -n "$SUB_PRIV_1" ] && [ "$SUB_PRIV_1" != "None" ]; then
      if aws ec2 describe-subnets --subnet-ids "$SUB_PRIV_1" --region us-east-1 >/dev/null 2>&1; then
        terraform import 'aws_subnet.private[0]' "$SUB_PRIV_1" || true
      fi
    fi

    SUB_PRIV_2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=TicketDesk-private-subnet-2" --region us-east-1 --query "Subnets[0].SubnetId" --output text 2>/dev/null || echo "")
    if [ -n "$SUB_PRIV_2" ] && [ "$SUB_PRIV_2" != "None" ]; then
      if aws ec2 describe-subnets --subnet-ids "$SUB_PRIV_2" --region us-east-1 >/dev/null 2>&1; then
        terraform import 'aws_subnet.private[1]' "$SUB_PRIV_2" || true
      fi
    fi

    # Import Route Tables & Associations
    RT_PUB=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=TicketDesk-public-rt" --region us-east-1 --query "RouteTables[0].RouteTableId" --output text 2>/dev/null || echo "")
    if [ -n "$RT_PUB" ] && [ "$RT_PUB" != "None" ]; then
      if aws ec2 describe-route-tables --route-table-ids "$RT_PUB" --region us-east-1 >/dev/null 2>&1; then
        terraform import aws_route_table.public "$RT_PUB" || true
        if [ -n "$SUB_PUB_1" ] && [ "$SUB_PUB_1" != "None" ]; then
          terraform import 'aws_route_table_association.public[0]' "$SUB_PUB_1/$RT_PUB" || true
        fi
        if [ -n "$SUB_PUB_2" ] && [ "$SUB_PUB_2" != "None" ]; then
          terraform import 'aws_route_table_association.public[1]' "$SUB_PUB_2/$RT_PUB" || true
        fi
      fi
    fi

    RT_PRIV=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=TicketDesk-private-rt" --region us-east-1 --query "RouteTables[0].RouteTableId" --output text 2>/dev/null || echo "")
    if [ -n "$RT_PRIV" ] && [ "$RT_PRIV" != "None" ]; then
      if aws ec2 describe-route-tables --route-table-ids "$RT_PRIV" --region us-east-1 >/dev/null 2>&1; then
        terraform import aws_route_table.private "$RT_PRIV" || true
        if [ -n "$SUB_PRIV_1" ] && [ "$SUB_PRIV_1" != "None" ]; then
          terraform import 'aws_route_table_association.private[0]' "$SUB_PRIV_1/$RT_PRIV" || true
        fi
        if [ -n "$SUB_PRIV_2" ] && [ "$SUB_PRIV_2" != "None" ]; then
          terraform import 'aws_route_table_association.private[1]' "$SUB_PRIV_2/$RT_PRIV" || true
        fi
      fi
    fi

    # Import NAT Gateway
    NAT_ID=$(aws ec2 describe-nat-gateways --filters "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --region us-east-1 --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null || echo "")
    if [ -n "$NAT_ID" ] && [ "$NAT_ID" != "None" ]; then
      terraform import aws_nat_gateway.nat "$NAT_ID" || true
    fi
  fi
fi

IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=TicketDesk-igw" --region us-east-1 --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "")
if [ -n "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
  if aws ec2 describe-internet-gateways --internet-gateway-ids "$IGW_ID" --region us-east-1 >/dev/null 2>&1; then
    echo "Importing existing Internet Gateway ($IGW_ID)..."
    terraform import aws_internet_gateway.igw "$IGW_ID" || true
  fi
fi

# 2. Security Groups
SG_ALB=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=TicketDesk-alb-sg" --region us-east-1 --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ -n "$SG_ALB" ] && [ "$SG_ALB" != "None" ]; then
  if aws ec2 describe-security-groups --group-ids "$SG_ALB" --region us-east-1 >/dev/null 2>&1; then
    terraform import aws_security_group.alb "$SG_ALB" || true
  fi
fi

SG_ECS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=TicketDesk-ecs-task-sg" --region us-east-1 --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ -n "$SG_ECS" ] && [ "$SG_ECS" != "None" ]; then
  if aws ec2 describe-security-groups --group-ids "$SG_ECS" --region us-east-1 >/dev/null 2>&1; then
    terraform import aws_security_group.ecs_task "$SG_ECS" || true
  fi
fi

SG_RDS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=TicketDesk-rds-sg" --region us-east-1 --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [ -n "$SG_RDS" ] && [ "$SG_RDS" != "None" ]; then
  if aws ec2 describe-security-groups --group-ids "$SG_RDS" --region us-east-1 >/dev/null 2>&1; then
    terraform import aws_security_group.rds "$SG_RDS" || true
  fi
fi

# 3. Load Balancer, Target Group & Listener
ALB_ARN=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region us-east-1 --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  if aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region us-east-1 >/dev/null 2>&1; then
    echo "Importing existing Load Balancer ticketdesk-alb..."
    terraform import aws_lb.main "$ALB_ARN" || true

    LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region us-east-1 --query "Listeners[0].ListenerArn" --output text 2>/dev/null || echo "")
    if [ -n "$LISTENER_ARN" ] && [ "$LISTENER_ARN" != "None" ]; then
      terraform import aws_lb_listener.http "$LISTENER_ARN" || true
    fi
  fi
fi

TG_ARN=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region us-east-1 --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  if aws elbv2 describe-target-groups --target-group-arns "$TG_ARN" --region us-east-1 >/dev/null 2>&1; then
    echo "Importing existing Target Group ticketdesk-tg ($TG_ARN)..."
    terraform import aws_lb_target_group.api "$TG_ARN" || true
  fi
fi


# 4. CloudWatch Log Group
if aws logs describe-log-groups --log-group-name-prefix "/ecs/TicketDesk-logs" --region us-east-1 | grep "/ecs/TicketDesk-logs" >/dev/null 2>&1; then
  echo "Importing existing CloudWatch log group..."
  terraform import aws_cloudwatch_log_group.ecs_logs "/ecs/TicketDesk-logs" || true
fi

# 5. Database Resources
if aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing DB Subnet Group ticketdesk-db-subnet-group..."
  terraform import aws_db_subnet_group.main "ticketdesk-db-subnet-group" || true
fi

if aws rds describe-db-instances --db-instance-identifier "ticketdesk-mysql-db" --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing RDS Instance ticketdesk-mysql-db..."
  terraform import aws_db_instance.main "ticketdesk-mysql-db" || true
fi

# 6. ECS & ECR
if aws ecs describe-clusters --clusters "TicketDesk-cluster" --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing ECS Cluster TicketDesk-cluster..."
  terraform import aws_ecs_cluster.main "TicketDesk-cluster" || true
fi

if aws ecr describe-repositories --repository-names ticketdesk-api --region us-east-1 >/dev/null 2>&1; then
  echo "Importing existing ECR repository ticketdesk-api..."
  terraform import aws_ecr_repository.api ticketdesk-api || true
fi

# 7. IAM Roles & Policies
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

# 8. Secrets & SSM Parameters
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

# 9. SNS Topic, Lambda & S3 Buckets
if [ -n "$ACCOUNT_ID" ]; then
  terraform import aws_sns_topic.alarms "arn:aws:sns:us-east-1:$ACCOUNT_ID:TicketDesk-alarms-topic" || true
fi

if aws lambda get-function --function-name "TicketDesk-thumbnail-generator" --region us-east-1 >/dev/null 2>&1; then
  terraform import aws_lambda_function.thumbnail_generator "TicketDesk-thumbnail-generator" || true
  if [ -n "$ACCOUNT_ID" ]; then
    terraform import aws_lambda_permission.allow_s3_invoke "TicketDesk-thumbnail-generator/AllowS3InvokeThumbnailGenerator-$ACCOUNT_ID" || true
  fi
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
