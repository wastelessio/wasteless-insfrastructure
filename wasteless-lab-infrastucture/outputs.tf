# ============================================
# Outputs
# ============================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "instances" {
  description = "EC2 instances created"
  value = {
    production_api = {
      id         = aws_instance.production_api.id
      public_ip  = aws_instance.production_api.public_ip
      type       = aws_instance.production_api.instance_type
      state      = aws_instance.production_api.instance_state
      tags       = aws_instance.production_api.tags
    }
    dev_old_app = {
      id         = aws_instance.dev_old_app.id
      public_ip  = aws_instance.dev_old_app.public_ip
      type       = aws_instance.dev_old_app.instance_type
      state      = aws_instance.dev_old_app.instance_state
      tags       = aws_instance.dev_old_app.tags
    }
    staging_forgotten = {
      id         = aws_instance.staging_forgotten.id
      public_ip  = aws_instance.staging_forgotten.public_ip
      type       = aws_instance.staging_forgotten.instance_type
      state      = aws_instance.staging_forgotten.instance_state
      tags       = aws_instance.staging_forgotten.tags
    }
    test_ancient = {
      id         = aws_instance.test_ancient.id
      public_ip  = aws_instance.test_ancient.public_ip
      type       = aws_instance.test_ancient.instance_type
      state      = aws_instance.test_ancient.instance_state
      tags       = aws_instance.test_ancient.tags
    }
  }
}

output "ebs_volumes" {
  description = "EBS volumes (orphaned for testing)"
  value = {
    orphaned_1 = {
      id   = aws_ebs_volume.orphaned_1.id
      size = aws_ebs_volume.orphaned_1.size
      type = aws_ebs_volume.orphaned_1.type
    }
    orphaned_2 = {
      id   = aws_ebs_volume.orphaned_2.id
      size = aws_ebs_volume.orphaned_2.size
      type = aws_ebs_volume.orphaned_2.type
    }
  }
}

output "rds_endpoint" {
  description = "RDS endpoint (if enabled)"
  value       = var.enable_rds ? aws_db_instance.dev_mysql[0].endpoint : "RDS not enabled"
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = {
    production_api    = "ssh -i ${var.key_name} ubuntu@${aws_instance.production_api.public_ip}"
    dev_old_app       = "ssh -i ${var.key_name} ubuntu@${aws_instance.dev_old_app.public_ip}"
    staging_forgotten = "ssh -i ${var.key_name} ubuntu@${aws_instance.staging_forgotten.public_ip}"
    test_ancient      = "ssh -i ${var.key_name} ubuntu@${aws_instance.test_ancient.public_ip}"
  }
}

output "cost_estimate" {
  description = "Monthly cost estimate"
  value = {
    ec2_instances = "~€${var.instance_types.active == "t3.micro" ? 8.50 : 4.25} + 3x€4.25 = ~€21/month"
    ebs_volumes   = "3 volumes x 8GB x €0.11/GB = ~€2.64/month"
    rds           = var.enable_rds ? "1x db.t3.micro = ~€15/month" : "€0 (disabled)"
    total         = var.enable_rds ? "~€38-40/month" : "~€23-25/month"
    note          = "Stop instances when not testing to reduce cost to ~€3/month (EBS only)"
  }
}

output "wasteless_test_scenarios" {
  description = "What you can test with this setup"
  value = {
    scenario_1 = "EC2 Idle Detection: 3 idle instances (dev_old_app, staging_forgotten, test_ancient)"
    scenario_2 = "Whitelist Protection: production_api has Critical=true tag (should NOT be stopped)"
    scenario_3 = "EBS Orphaned: 2 orphaned volumes (orphaned_1, orphaned_2)"
    scenario_4 = "Auto-Remediation: Stop idle instances, verify savings"
    scenario_5 = "Rollback Test: Restart stopped instance"
    scenario_6 = "RDS Idle: Dev MySQL with 0 connections (if enabled)"
  }
}