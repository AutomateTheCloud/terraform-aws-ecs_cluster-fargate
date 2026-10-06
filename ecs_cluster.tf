# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_ecs_cluster" "this" {
  region = var.region
  name   = local.cluster_name

  configuration {
    execute_command_configuration {
      logging    = var.execute_command.logging
      kms_key_id = var.execute_command.kms_key_id

      dynamic "log_configuration" {
        for_each = local.create_log_group ? [1] : []
        content {
          cloud_watch_log_group_name = aws_cloudwatch_log_group.this[0].name
          # ECS Exec refuses to start a session when this is true and the log group is not
          # encrypted with a KMS key, so it follows the log group's key.
          cloud_watch_encryption_enabled = var.execute_command.log_group.kms_key_id != null
        }
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  tags = merge(local.tags, { Name = local.cluster_name })

  lifecycle {
    precondition {
      condition     = can(regex("^[A-Za-z0-9_-]{1,255}$", local.cluster_name))
      error_message = "The cluster name \"${local.cluster_name}\" is not valid: ECS allows 1 to 255 letters, numbers, hyphens and underscores. Check details.environment_abbr, which is used as given."
    }
  }
}
