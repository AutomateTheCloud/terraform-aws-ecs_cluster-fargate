# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Receives the output of ECS Exec commands when execute_command.logging is OVERRIDE.
resource "aws_cloudwatch_log_group" "this" {
  count = local.create_log_group ? 1 : 0

  region            = var.region
  name              = "/ecs_cluster/${local.cluster_name}"
  retention_in_days = var.execute_command.log_group.retention_in_days
  kms_key_id        = var.execute_command.log_group.kms_key_id

  tags = local.tags
}
