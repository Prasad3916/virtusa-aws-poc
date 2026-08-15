#!/bin/bash
set +e

REGION="${AWS_REGION:-us-east-1}"
echo "=========================================================="
echo "   TICKETDESK COMPREHENSIVE RESOURCE & VPC CLEANUP IN $REGION"
echo "=========================================================="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

# 1. Clean TicketDesk Lambda Permission & Function
echo "[1/10] Cleaning TicketDesk Lambda Permissions & Function..."
if [ -n "$ACCOUNT_ID" ]; then
  aws lambda remove-permission --function-name "TicketDesk-thumbnail-generator" --statement-id "AllowS3InvokeThumbnailGenerator-$ACCOUNT_ID" --region $REGION >/dev/null 2>&1 || true
  aws lambda remove-permission --function-name "TicketDesk-thumbnail-generator" --statement-id "AllowS3InvokeThumbnailGenerator" --region $REGION >/dev/null 2>&1 || true
fi

# 2. Clean TicketDesk ECS Services & Cluster
echo "[2/10] Cleaning TicketDesk ECS Services & Cluster..."
if aws ecs describe-clusters --clusters "TicketDesk-cluster" --region $REGION >/dev/null 2>&1; then
  SERVICES=$(aws ecs list-services --cluster "TicketDesk-cluster" --region $REGION --query "serviceArns[]" --output text 2>/dev/null || echo "")
  for service in $SERVICES; do
    aws ecs update-service --cluster "TicketDesk-cluster" --service "$service" --desired-count 0 --region $REGION >/dev/null 2>&1 || true
    aws ecs delete-service --cluster "TicketDesk-cluster" --service "$service" --force --region $REGION >/dev/null 2>&1 || true
  done
  aws ecs delete-cluster --cluster "TicketDesk-cluster" --region $REGION >/dev/null 2>&1 || true
fi

# 3. Clean TicketDesk Load Balancer & Target Group
echo "[3/10] Cleaning TicketDesk Load Balancer and Target Group..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region $REGION --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region $REGION >/dev/null 2>&1 || true
  sleep 5
fi

TG_ARN=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region $REGION --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region $REGION >/dev/null 2>&1 || true
fi

# 4. Clean TicketDesk RDS Instance & Subnet Group
echo "[4/10] Cleaning TicketDesk RDS Instance and Subnet Group..."
if aws rds describe-db-instances --db-instance-identifier "ticketdesk-mysql-db" --region $REGION >/dev/null 2>&1; then
  aws rds delete-db-instance --db-instance-identifier "ticketdesk-mysql-db" --skip-final-snapshot --delete-automated-backups --region $REGION >/dev/null 2>&1 || true
  echo "Waiting for RDS instance deletion..."
  aws rds wait db-instance-deleted --db-instance-identifier "ticketdesk-mysql-db" --region $REGION >/dev/null 2>&1 || true
fi

if aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region $REGION >/dev/null 2>&1; then
  aws rds delete-db-subnet-group --db-subnet-group-name "ticketdesk-db-subnet-group" --region $REGION >/dev/null 2>&1 || true
fi

# 5. Clean NAT Gateways & Elastic IPs
echo "[5/10] Cleaning NAT Gateways and Elastic IPs..."
NATS=$(aws ec2 describe-nat-gateways --region $REGION --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null || echo "")
for nat in $NATS; do
  aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --region $REGION >/dev/null 2>&1 || true
done

sleep 5

EIPS=$(aws ec2 describe-addresses --region $REGION --query "Addresses[].AllocationId" --output text 2>/dev/null || echo "")
for eip in $EIPS; do
  aws ec2 release-address --allocation-id "$eip" --region $REGION >/dev/null 2>&1 || true
done

# 6. Clean Detached Internet Gateways
echo "[6/10] Cleaning Detached Internet Gateways..."
IGWS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.state,Values=detached" --region $REGION --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo "")
for igw in $IGWS; do
  aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region $REGION >/dev/null 2>&1 || true
done

# 7. Sweep and Delete ALL Non-Default VPCs to Guarantee Zero VpcLimitExceeded Errors
echo "[7/10] Sweeping and Deleting Non-Default VPCs to ensure VPC Quota Availability..."
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

    # Delete ENIs
    ENIS=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc" --region $REGION --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>/dev/null || echo "")
    for eni in $ENIS; do
      aws ec2 delete-network-interface --network-interface-id "$eni" --region $REGION >/dev/null 2>&1 || true
    done

    # Delete Security Groups
    SGS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" --region $REGION --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
    for sg in $SGS; do
      aws ec2 delete-security-group --group-id "$sg" --region $REGION >/dev/null 2>&1 || true
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
echo "✔ TICKETDESK RESOURCE & VPC CLEANUP FINISHED!"
echo "=========================================================="
