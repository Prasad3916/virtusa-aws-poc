#!/bin/bash
set +e

REGION="${AWS_REGION:-us-east-1}"
echo "=========================================================="
echo "   TICKETDESK SCOPED AWS RESOURCE CLEANUP IN $REGION"
echo "=========================================================="

# 1. Delete TicketDesk ECS Services & Clusters
echo "[1/10] Cleaning TicketDesk ECS Services & Cluster..."
if aws ecs describe-clusters --clusters "TicketDesk-cluster" --region $REGION >/dev/null 2>&1; then
  SERVICES=$(aws ecs list-services --cluster "TicketDesk-cluster" --region $REGION --query "serviceArns[]" --output text 2>/dev/null || echo "")
  for service in $SERVICES; do
    aws ecs update-service --cluster "TicketDesk-cluster" --service "$service" --desired-count 0 --region $REGION >/dev/null 2>&1 || true
    aws ecs delete-service --cluster "TicketDesk-cluster" --service "$service" --force --region $REGION >/dev/null 2>&1 || true
  done
  aws ecs delete-cluster --cluster "TicketDesk-cluster" --region $REGION >/dev/null 2>&1 || true
fi

# 2. Delete TicketDesk Load Balancer & Target Group
echo "[2/10] Cleaning TicketDesk Load Balancer and Target Group..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names "ticketdesk-alb" --region $REGION --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region $REGION >/dev/null 2>&1 || true
  sleep 5
fi

TG_ARN=$(aws elbv2 describe-target-groups --names "ticketdesk-tg" --region $REGION --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region $REGION >/dev/null 2>&1 || true
fi

# 3. Delete TicketDesk RDS Instance & Subnet Group
echo "[3/10] Cleaning TicketDesk RDS Instance and Subnet Group..."
if aws rds describe-db-instances --db-instance-identifier "ticketdesk-mysql-db" --region $REGION >/dev/null 2>&1; then
  aws rds delete-db-instance --db-instance-identifier "ticketdesk-mysql-db" --skip-final-snapshot --delete-automated-backups --region $REGION >/dev/null 2>&1 || true
  # Wait for RDS instance deletion
  echo "Waiting for RDS instance deletion..."
  aws rds wait db-instance-deleted --db-instance-identifier "ticketdesk-mysql-db" --region $REGION >/dev/null 2>&1 || true
fi

if aws rds describe-db-subnet-groups --db-subnet-group-name "ticketdesk-db-subnet-group" --region $REGION >/dev/null 2>&1; then
  aws rds delete-db-subnet-group --db-subnet-group-name "ticketdesk-db-subnet-group" --region $REGION >/dev/null 2>&1 || true
fi

# 4. Clean Unattached Elastic IPs & NAT Gateways
echo "[4/10] Cleaning TicketDesk NAT Gateways and Elastic IPs..."
NATS=$(aws ec2 describe-nat-gateways --filters "Name=tag:Project,Values=TicketDesk" --region $REGION --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null || echo "")
for nat in $NATS; do
  aws ec2 delete-nat-gateway --nat-gateway-id "$nat" --region $REGION >/dev/null 2>&1 || true
done

EIPS=$(aws ec2 describe-addresses --filters "Name=tag:Project,Values=TicketDesk" --region $REGION --query "Addresses[].AllocationId" --output text 2>/dev/null || echo "")
for eip in $EIPS; do
  aws ec2 release-address --allocation-id "$eip" --region $REGION >/dev/null 2>&1 || true
done

# Also release any unattached EIPs
UNATTACHED=$(aws ec2 describe-addresses --region $REGION --query "Addresses[?AssociationId==null].AllocationId" --output text 2>/dev/null || echo "")
for ueip in $UNATTACHED; do
  aws ec2 release-address --allocation-id "$ueip" --region $REGION >/dev/null 2>&1 || true
done

# 5. Clean Detached Internet Gateways
echo "[5/10] Cleaning Detached Internet Gateways..."
IGWS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.state,Values=detached" --region $REGION --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo "")
for igw in $IGWS; do
  aws ec2 delete-internet-gateway --internet-gateway-id "$igw" --region $REGION >/dev/null 2>&1 || true
done

# 6. Delete TicketDesk VPC & Subnets
echo "[6/10] Cleaning TicketDesk VPCs, Subnets, and Gateways..."
VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=TicketDesk" --region $REGION --query "Vpcs[].VpcId" --output text 2>/dev/null || echo "")
if [ -z "$VPCS" ] || [ "$VPCS" = "None" ]; then
  VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=TicketDesk-vpc" --region $REGION --query "Vpcs[].VpcId" --output text 2>/dev/null || echo "")
fi

for vpc in $VPCS; do
  if [ -n "$vpc" ] && [ "$vpc" != "None" ]; then
    echo "Processing cleanup for TicketDesk VPC: $vpc"
    
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
echo "✔ TICKETDESK SCOPED AWS RESOURCE CLEANUP COMPLETE!"
echo "=========================================================="
