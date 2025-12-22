# ============================================
# Wasteless Lab - Main Infrastructure
# ============================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "Wasteless testing"
    }
  }
}

# ============================================
# Data Sources
# ============================================

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================
# VPC & Networking
# ============================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================
# Security Groups
# ============================================

resource "aws_security_group" "allow_ssh" {
  name        = "${var.project_name}-allow-ssh"
  description = "Allow SSH from your IP"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip]
  }
  
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-allow-ssh"
  }
}

# ============================================
# EC2 Instances
# ============================================

# User data to simulate load on "active" instance
locals {
  active_userdata = <<-EOF
    #!/bin/bash
    # Simulate active workload (light CPU usage ~20%)
    apt-get update
    apt-get install -y stress-ng

    # Run stress in background (20% CPU)
    nohup stress-ng --cpu 1 --cpu-load 20 --timeout 0 &

    echo "Active instance initialized" > /var/log/wasteless-active.log
  EOF

  # User data for idle instances (no load)
  idle_userdata = <<-EOF
    #!/bin/bash
    # This instance will be idle (for waste detection)
    echo "Idle instance - no workload" > /var/log/wasteless-idle.log

    # Just run sshd, nothing else
  EOF
}

# ============================================
# Instance 1: ACTIVE (Production - WHITELIST)
# ============================================

resource "aws_instance" "production_api" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_types.active  # t3.micro
  key_name      = var.key_name
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = local.active_userdata
  
  tags = {
    Name        = "production-api"
    Environment = "production"
    Critical    = "true"  # Should be WHITELISTED
    Application = "api-server"
    Wasteless   = "ignore"  # Alternative whitelist tag
  }
}

# ============================================
# Instance 2: IDLE (Dev - old app)
# ============================================

resource "aws_instance" "dev_old_app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_types.idle  # t3.nano
  key_name      = var.key_name
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = local.idle_userdata
  
  tags = {
    Name        = "dev-old-app"
    Environment = "development"
    Application = "legacy-app"
    Owner       = "team-backend"
  }
}

# ============================================
# Instance 3: IDLE (Staging - forgotten)
# ============================================

resource "aws_instance" "staging_forgotten" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_types.idle  # t3.nano
  key_name      = var.key_name
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = local.idle_userdata
  
  tags = {
    Name        = "staging-forgotten"
    Environment = "staging"
    Application = "test-app"
    Owner       = "team-frontend"
  }
}

# ============================================
# Instance 4: IDLE (Test - ancient)
# This one is old and should have HIGH confidence
# ============================================

resource "aws_instance" "test_ancient" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_types.idle  # t3.nano
  key_name      = var.key_name
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  user_data = local.idle_userdata
  
  tags = {
    Name        = "test-server-old"
    Environment = "test"
    Application = "experiments"
    Owner       = "team-data"
    CreatedDate = "2024-01-15"  # Fake old date
  }
}

# ============================================
# EBS Volumes (Orphaned - for waste detection)
# ============================================

resource "aws_ebs_volume" "orphaned_1" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 8  # 8GB
  type              = "gp3"
  
  tags = {
    Name        = "orphaned-volume-1"
    Environment = "development"
    Status      = "unused"
  }
}

resource "aws_ebs_volume" "orphaned_2" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 10  # 10GB
  type              = "gp3"
  
  tags = {
    Name        = "orphaned-volume-2"
    Environment = "staging"
    Status      = "detached"
  }
}

# ============================================
# Temporary volume (will be attached then detached for testing)
# ============================================

resource "aws_ebs_volume" "temp_volume" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 5
  type              = "gp3"
  
  tags = {
    Name        = "temp-volume-for-testing"
    Environment = "test"
  }
}

# Attach to test instance initially
resource "aws_volume_attachment" "temp_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.temp_volume.id
  instance_id = aws_instance.test_ancient.id
  
  # This will be manually detached later for orphaned volume testing
}

# ============================================
# RDS Instance (OPTIONAL - adds cost)
# ============================================

resource "aws_db_subnet_group" "main" {
  count = var.enable_rds ? 1 : 0
  
  name       = "${var.project_name}-db-subnet"
  subnet_ids = [aws_subnet.public.id]
  
  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  count = var.enable_rds ? 1 : 0
  
  name        = "${var.project_name}-rds-sg"
  description = "Allow MySQL access from instances"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description     = "MySQL from instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_ssh.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

resource "aws_db_instance" "dev_mysql" {
  count = var.enable_rds ? 1 : 0
  
  identifier     = "${var.project_name}-dev-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = false  # Save cost
  
  db_name  = "testdb"
  username = "admin"
  password = "ChangeMeInProduction123!"  # Use AWS Secrets Manager in prod
  
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  
  skip_final_snapshot       = true
  final_snapshot_identifier = null
  
  backup_retention_period = 0  # No backups to save cost
  
  publicly_accessible = false
  
  tags = {
    Name        = "dev-mysql-idle"
    Environment = "development"
    Application = "testing"
  }
}