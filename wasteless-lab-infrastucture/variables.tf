# ============================================
# Wasteless Lab - Variables
# ============================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "wasteless-lab"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "test"
}

variable "your_ip" {
  description = "Your IP for SSH access (CIDR notation)"
  type        = string
  # Récupérer ton IP : curl ifconfig.me
  # Puis ajouter /32 : ex. "82.123.45.67/32"
}

variable "enable_rds" {
  description = "Enable RDS instance (adds ~€15/month)"
  type        = bool
  default     = false  # Set to true if you want to test RDS detection
}

variable "instance_types" {
  description = "Instance types to use"
  type = object({
    active = string  # Production instance
    idle   = string  # Idle instances
  })
  default = {
    active = "t3.micro"  # €8.50/month
    idle   = "t3.nano"   # €4.25/month
  }
}

variable "key_name" {
  description = "SSH key name (must exist in AWS)"
  type        = string
  # Create key first: aws ec2 create-key-pair --key-name wasteless-lab --query 'KeyMaterial' --output text > wasteless-lab.pem
}