# 1. Security Group for Application Load Balancer (Checklist #10)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security Group for Public Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP ingress from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# 2. Security Group for ECS Tasks (Checklist #11)
resource "aws_security_group" "ecs_task" {
  name        = "${var.project_name}-ecs-task-sg"
  description = "Security Group for ECS Fargate API tasks"
  vpc_id      = aws_vpc.main.id

  # Strict Security SG Chaining: Ingress ONLY from ALB SG
  ingress {
    description     = "Allow app traffic strictly from ALB SG"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic for dependencies"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-task-sg"
  }
}

# 3. Security Group for RDS MySQL Database (Checklist #12)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security Group for RDS MySQL Database"
  vpc_id      = aws_vpc.main.id

  # Strict Security SG Chaining: Ingress ONLY from ECS Task SG
  ingress {
    description     = "Allow MySQL ingress strictly from ECS Tasks SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_task.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}
