#!/bin/bash
REGION="${AWS_REGION:-us-east-1}"
echo "=========================================================="
echo "      FORCEFULLY DELETING ALL AWS RESOURCES IN $REGION"
echo "=========================================================="

# 1. Delete ECS Services & Clusters
echo "[1/12] Deleting ECS Services and Clusters..."
CLUSTERS=$(aws ecs list-clusters --region $REGION --query "clusterArns[]" --output text 2>/dev/null || echo "")
for cluster in $CLUSTERS; do
  SERVICES=$(aws ecs list-services --cluster $cluster --region $REGION --query "serviceArns[]" --output text 2>/dev/null || echo "")
  for service in $SERVICES; do
    aws ecs update-service --cluster $cluster --service $service --desired-count 0 --region $REGION >/dev/null 2>&1 || true
    aws ecs delete-service --cluster $cluster --service $service --force --region $REGION >/dev/null 2>&1 || true
  done
  aws ecs delete-cluster --cluster $cluster --region $REGION >/dev/null 2>&1 || true
done

# 2. Delete Load Balancers, Listeners & Target Groups
echo "[2/12] Deleting Load Balancers and Target Groups..."
ALBS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[].LoadBalancerArn" --output text 2>/dev/null || echo "")
for alb in $ALBS; do
  aws elbv2 delete-load-balancer --load-balancer-arn $alb --region $REGION >/dev/null 2>&1 || true
done

TGS=$(aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[].TargetGroupArn" --output text 2>/dev/null || echo "")
for tg in $TGS; do
  aws elbv2 delete-target-group --target-group-arn $tg --region $REGION >/dev/null 2>&1 || true
done

# 3. Delete RDS DB Instances & Subnet Groups
echo "[3/12] Deleting RDS Database Instances and Subnet Groups..."
DBS=$(aws rds describe-db-instances --region $REGION --query "DBInstances[].DBInstanceIdentifier" --output text 2>/dev/null || echo "")
for db in $DBS; do
  aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot --delete-automated-backups --region $REGION >/dev/null 2>&1 || true
done

GROUPS=$(aws rds describe-db-subnet-groups --region $REGION --query "DBSubnetGroups[].DBSubnetGroupName" --output text 2>/dev/null || echo "")
for grp in $GROUPS; do
  aws rds delete-db-subnet-group --db-subnet-group-name $grp --region $REGION >/dev/null 2>&1 || true
done

# 4. Delete S3 Buckets (Empty & Delete All Buckets)
echo "[4/12] Emptying and Deleting all S3 Buckets..."
BUCKETS=$(aws s3api list-buckets --query "Buckets[].Name" --output text 2>/dev/null || echo "")
for b in $BUCKETS; do
  echo "Deleting objects from bucket: $b"
  aws s3 rm "s3://$b" --recursive --region $REGION >/dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "$b" --region $REGION >/dev/null 2>&1 || true
done

# 5. Delete Lambda Functions
echo "[5/12] Deleting Lambda Functions..."
LAMBDAS=$(aws lambda list-functions --region $REGION --query "Functions[].FunctionName" --output text 2>/dev/null || echo "")
for fn in $LAMBDAS; do
  aws lambda delete-function --function-name $fn --region $REGION >/dev/null 2>&1 || true
done

# 6. Delete ECR Repositories
echo "[6/12] Deleting ECR Repositories..."
ECRS=$(aws ecr describe-repositories --region $REGION --query "repositories[].repositoryName" --output text 2>/dev/null || echo "")
for ecr in $ECRS; do
  aws ecr delete-repository --repository-name $ecr --force --region $REGION >/dev/null 2>&1 || true
done

# 7. Delete Secrets Manager Secrets
echo "[7/12] Deleting Secrets Manager Secrets..."
SECRETS=$(aws secretsmanager list-secrets --region $REGION --query "SecretList[].ARN" --output text 2>/dev/null || echo "")
for sec in $SECRETS; do
  aws secretsmanager delete-secret --secret-id $sec --force-delete-without-recovery --region $REGION >/dev/null 2>&1 || true
done

# 8. Delete SSM Parameters
echo "[8/12] Deleting SSM Parameters..."
PARAMS=$(aws ssm describe-parameters --region $REGION --query "Parameters[].Name" --output text 2>/dev/null || echo "")
for param in $PARAMS; do
  aws ssm delete-parameter --name "$param" --region $REGION >/dev/null 2>&1 || true
done

# 9. Delete CloudWatch Alarms, Dashboards & Log Groups
echo "[9/12] Deleting CloudWatch Alarms, Dashboards, and Log Groups..."
ALARMS=$(aws cloudwatch describe-alarms --region $REGION --query "MetricAlarms[].AlarmName" --output text 2>/dev/null || echo "")
if [ -n "$ALARMS" ]; then
  aws cloudwatch delete-alarms --alarm-names $ALARMS --region $REGION >/dev/null 2>&1 || true
fi

DASHBOARDS=$(aws cloudwatch list-dashboards --region $REGION --query "DashboardEntries[].DashboardName" --output text 2>/dev/null || echo "")
if [ -n "$DASHBOARDS" ]; then
  aws cloudwatch delete-dashboards --dashboard-names $DASHBOARDS --region $REGION >/dev/null 2>&1 || true
fi

LOGS=$(aws logs describe-log-groups --region $REGION --query "logGroups[].logGroupName" --output text 2>/dev/null || echo "")
for log in $LOGS; do
  aws logs delete-log-group --log-group-name "$log" --region $REGION >/dev/null 2>&1 || true
done

# 10. Delete NAT Gateways, EIPs, Gateways & VPCs
echo "[10/12] Deleting NAT Gateways and Elastic IPs..."
NATS=$(aws ec2 describe-nat-gateways --region $REGION --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null || echo "")
for nat in $NATS; do
  aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $REGION >/dev/null 2>&1 || true
done

# Wait for NAT Gateways to delete
sleep 15

EIPS=$(aws ec2 describe-addresses --region $REGION --query "Addresses[].AllocationId" --output text 2>/dev/null || echo "")
for eip in $EIPS; do
  aws ec2 release-address --allocation-id $eip --region $REGION >/dev/null 2>&1 || true
done

VPCS=$(aws ec2 describe-vpcs --region $REGION --query "Vpcs[?IsDefault==\`false\`].VpcId" --output text 2>/dev/null || echo "")
for vpc in $VPCS; do
  # Delete Security Groups in VPC
  SGS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$vpc" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
  for sg in $SGS; do
    aws ec2 delete-security-group --group-id $sg --region $REGION >/dev/null 2>&1 || true
  done

  # Detach & Delete IGWs
  IGWS=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$vpc" --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo "")
  for igw in $IGWS; do
    aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc --region $REGION >/dev/null 2>&1 || true
    aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $REGION >/dev/null 2>&1 || true
  done

  # Delete Subnets
  SUBNETS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$vpc" --query "Subnets[].SubnetId" --output text 2>/dev/null || echo "")
  for sub in $SUBNETS; do
    aws ec2 delete-subnet --subnet-id $sub --region $REGION >/dev/null 2>&1 || true
  done

  aws ec2 delete-vpc --vpc-id $vpc --region $REGION >/dev/null 2>&1 || true
done

# 11. Delete TicketDesk IAM Roles and Policies
echo "[11/12] Deleting TicketDesk IAM Roles and Policies..."
ROLES=("TicketDesk-ecs-execution-role" "TicketDesk-ecs-task-role" "TicketDesk-lambda-role")
for role in "${ROLES[@]}"; do
  POLICIES=$(aws iam list-attached-role-policies --role-name "$role" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo "")
  for pol in $POLICIES; do
    aws iam detach-role-policy --role-name "$role" --policy-arn "$pol" >/dev/null 2>&1 || true
  done
  aws iam delete-role --role-name "$role" >/dev/null 2>&1 || true
done

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [ -n "$ACCOUNT_ID" ]; then
  aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-ecs-task-s3-policy" >/dev/null 2>&1 || true
  aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-lambda-policy" >/dev/null 2>&1 || true
  aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/TicketDesk-ecs-execution-secrets-policy" >/dev/null 2>&1 || true
fi

echo "=========================================================="
echo "✔ COMPLETE AWS ACCOUNT RESOURCE WIPEOUT FINISHED!"
echo "=========================================================="
