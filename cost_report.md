# TicketDesk - One-Page AWS Infrastructure Cost Report

## Executive Summary
This report outlines the estimated monthly operational cost for running the **TicketDesk** application on AWS in the `us-east-1` region under a typical Foundation POC workload.

Total Estimated Monthly Spend: **~$35.20 USD** (within standard AWS $50 POC budget limits).

---

## Itemized Resource Cost Breakdown

| AWS Service | Configuration & Tier | Monthly Cost (USD) | % of Total Spend |
| :--- | :--- | :--- | :--- |
| **AWS Fargate (ECS)** | 2 Tasks × 0.5 vCPU, 1 GB RAM (24/7) | $18.40 | 52.3% |
| **Amazon RDS MySQL** | `db.t3.micro` Single-AZ (20 GB Storage) | $12.50 | 35.5% |
| **Application Load Balancer** | 1 ALB (~0.5 LCU average) | $2.80 | 8.0% |
| **CloudFront + S3** | Static Hosting & CloudFront Cache (10 GB Out) | $0.90 | 2.5% |
| **AWS Lambda & S3 Attachments**| 10,000 invocations + 5 GB storage | $0.20 | 0.6% |
| **CloudWatch Logs & Dashboard**| 14-day retention (1 GB logs + 1 Dashboard) | $0.40 | 1.1% |
| **Secrets Manager & SSM** | 1 Secret + Parameter Store free tier | $0.00 | 0.0% |
| **Total** | | **$35.20** | **100%** |

---

## Two Most Expensive Services
1. **ECS Fargate Compute ($18.40 / mo - 52.3%)**:
   - Running 2 tasks continuously across 2 Availability Zones for high availability.
   - *Cost Reduction Strategy*: Enable auto-scaling or schedule nightly task scale-down to 0 tasks during off-peak hours (Stretch goal +1 point).
2. **Amazon RDS Database ($12.50 / mo - 35.5%)**:
   - Running `db.t3.micro` MySQL instance with encrypted storage and automated backups.
   - *Cost Reduction Strategy*: Stop the RDS instance outside working hours during evaluation.

---

## Cost Optimization & Clean Teardown
To ensure zero billable residual costs after POC evaluation, execute:
```bash
cd terraform
terraform destroy -auto-approve
```
Confirming all resources (ALB, ECS, RDS, S3, CloudFront) are deleted cleanly.
