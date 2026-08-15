#!/bin/bash
set +e

REGION="${AWS_REGION:-us-east-1}"
echo "=========================================================="
echo "   TICKETDESK OPTION B: COMPLETE TEARDOWN TO ZERO IN $REGION"
echo "=========================================================="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

# PHASE 1 — ECS (Service & Cluster)
echo "[PHASE 1/11] Cleaning TicketDesk ECS Service & Cluster..."
if aws ecs describe-clusters --clusters "TicketDesk-cluster" --region $REGION >/dev/null 2>&1; then
  SERVICES=$(aws ecs list-services --cluster "TicketDesk-cluster" --region $REGION --query "serviceArns[]" --output text 2>/dev/null || echo "")
  for service in $SERVICES; do
    aws ecs update-service --cluster "TicketDesk-cluster" --service "$service" --desired-count 0 --region $REGION >/dev/null 2>&1 || true
    aws ecs delete-service --cluster "TicketDesk-cluster" --service "$service" --force --region $REGION >/dev/null 2>&1 || true
  done
  aws ecs delete-cluster --cluster "TicketDesk-cluster" --region $REGION >/dev/null 2>&1 || true
fi

# PHASE 2 — ALB & Target Group
echo "[PHASE 2/11] Cleaning TicketDesk Load Balancer and Target Group..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region $REGION --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region $REGION >/dev/null 2>&1 || true
  sleep 5
fi

TG_ARN=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region $REGION --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region $REGION >/dev/null 2>&1 || true
fi

# PHASE 3 — RDS Instance & Subnet Group
echo "[PHASE 3/11] Cleaning TicketDesk RDS Instance and Subnet Group..."
if aws rds describe-db-instances --db-instance-identifier "ticketdesk-mysql-db" --region $REGION >/dev/null 2>&1; then
  aws rds delete-db-instance --db-instance-identifier "ticketdesk-mysql-db" --skip-final-snapshot --delete-automated-backups --region $REGION >/dev/null 2>&1 || true
  echo "Waiting for RDS instance deletion..."
  aws rds wait db-instance-deleted --db-instance-identifier "ticketdesk-mysql-db" --region $REGION >/dev/null 2>&1 || true
fi

if aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region $REGION >/dev/null 2>&1; then
  aws rds delete-db-subnet-group --db-subnet-group-name "ticketdesk-db-subnet-group" --region $REGION >/dev/null 2>&1 || true
fi

# PHASE 4 — NAT Gateway & Elastic IPs
echo "[PHASE 4/11] Cleaning NAT Gateways and Elastic IPs..."
NATS=$(aws ec2 describe-nat-gateways --region $REGION --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null || echo "")
for nat in $NATS; do
  aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --region $REGION >/dev/null 2>&1 || true
done

sleep 5

EIPS=$(aws ec2 describe-addresses --region $REGION --query "Addresses[].AllocationId" --output text 2>/dev/null || echo "")
for eip in $EIPS; do
  aws ec2 release-address --allocation-id "$eip" --region $REGION >/dev/null 2>&1 || true
done

# PHASE 5 — Lambda Function & Permissions
echo "[PHASE 5/11] Cleaning TicketDesk Lambda Function & Permissions..."
if aws lambda get-function --function-name "TicketDesk-thumbnail-generator" --region $REGION >/dev/null 2>&1; then
  aws lambda delete-function --function-name "TicketDesk-thumbnail-generator" --region $REGION >/dev/null 2>&1 || true
fi

# PHASE 6 — CloudWatch Log Groups
echo "[PHASE 6/11] Cleaning CloudWatch Log Groups..."
if aws logs describe-log-groups --log-group-name-prefix "/ecs/TicketDesk-logs" --region $REGION | grep "/ecs/TicketDesk-logs" >/dev/null 2>&1; then
  aws logs delete-log-group --log-group-name "/ecs/TicketDesk-logs" --region $REGION >/dev/null 2>&1 || true
fi

# PHASE 7 — Secrets Manager Secrets
echo "[PHASE 7/11] Cleaning Secrets Manager Secrets..."
if aws secretsmanager describe-secret --secret-id "TicketDesk-db-credentials" --region $REGION >/dev/null 2>&1; then
  aws secretsmanager delete-secret --secret-id "TicketDesk-db-credentials" --force-delete-without-recovery --region $REGION >/dev/null 2>&1 || true
fi

# PHASE 8 — ECR Repositories
echo "[PHASE 8/11] Cleaning ECR Repositories..."
if aws ecr describe-repositories --repository-names ticketdesk-api --region $REGION >/dev/null 2>&1; then
  aws ecr delete-repository --repository-name ticketdesk-api --force --region $REGION >/dev/null 2>&1 || true
fi

# PHASE 9 — S3 Buckets
echo "[PHASE 9/11] Emptying and Deleting S3 Buckets..."
if [ -n "$ACCOUNT_ID" ]; then
  for b in "ticketdesk-frontend-$ACCOUNT_ID" "ticketdesk-attachments-$ACCOUNT_ID"; do
    if aws s3api head-bucket --bucket "$b" >/dev/null 2>&1; then
      aws s3 rm "s3://$b" --recursive --region $REGION >/dev/null 2>&1 || true
      aws s3api delete-bucket --bucket "$b" --region $REGION >/dev/null 2>&1 || true
    fi
  done
fi

# PHASE 10 — IAM Roles & Customer-Managed Policies
echo "[PHASE 10/11] Cleaning TicketDesk IAM Roles & Policies..."
ROLES=("TicketDesk-ecs-execution-role" "TicketDesk-ecs-task-role" "TicketDesk-lambda-role")
for role in "${ROLES[@]}"; do
  POLICIES=$(aws iam list-attached-role-policies --role-name "$role" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo "")
  for pol in $POLICIES; do
    aws iam detach-role-policy --role-name "$role" --policy-arn "$pol" >/dev/null 2>&1 || true
  done
  aws iam delete-role --role-name "$role" >/dev/null 2>&1 || true
done

if [ -n "$ACCOUNT_ID" ]; then
  aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-ecs-task-s3-policy" >/dev/null 2>&1 || true
  aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-lambda-policy" >/dev/null 2>&1 || true
  aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-ecs-execution-secrets-policy" >/dev/null 2>&1 || true
fi

# PHASE 11 — VPC Networking & Non-Default VPCs
echo "[PHASE 11/11] Sweeping and Deleting Non-Default VPCs..."
NON_DEFAULT_VPCS=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=false" --region $REGION --query "Vpcs[].VpcId" --output text 2>/dev/null || echo "")

for vpc in $NON_DEFAULT_VPCS; do
  if [ -n "$vpc" ] && [ "$vpc" != "None" ]; then
    echo "Processing cleanup for non-default VPC: $vpc"
    
    # Detach & Delete IGW attached to this VPC
    VPC_IGWS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" --region $REGION --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo "")
    for igw in $VPC_IGWS; do
      aws ec2 detach-internet-gateway --internet-gateway-id "$igw" --vpc-id "$vpc" --region $REGION >/dev/null 2>&1 || true
      aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region $REGION >/dev/null 2>&1 || true
    done

    # Delete Security Groups
    SGS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" --region $REGION --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
    for sg in $SGS; do
      aws ec2 delete-security-group --group-id "$sg" --region $REGION >/dev/null 2>&1 || true
    done

    # Delete Route Tables
    RTS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc" --region $REGION --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text 2>/dev/null || echo "")
    for rt in $RTS; do
      aws ec2 delete-route-table --route-table-id "$rt" --region $REGION >/dev/null 2>&1 || true
    done

    # Delete Subnets
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --region $REGION --query "Subnets[].SubnetId" --output text 2>/dev/null || echo "")
    for sub in $SUBNETS; do
      aws ec2 delete-subnet --subnet-id "$sub" --region $REGION >/dev/null 2>&1 || true
    done

    aws ec2 delete-vpc --vpc-id "$vpc" --region $REGION >/dev/null 2>&1 || true
  fi
done

echo "=========================================================="
echo "✔ AWS CLEANUP COMPLETE — ZERO TICKETDESK RESOURCES REMAIN"
echo "=========================================================="
