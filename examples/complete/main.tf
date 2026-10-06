# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# An ECS cluster for Fargate tasks with:
#
# - ECS Exec sessions encrypted with a customer managed KMS key, and their output logged
#   to a CloudWatch Logs log group the module creates, encrypted with the same key.
# - Enhanced Container Insights.
# - A default capacity provider strategy: the first task on Fargate, then three of every
#   four on Fargate Spot.
# - An IAM policy with the permissions a task role needs for ECS Exec on this cluster.
#   Attach it to the task role of each service you turn ECS Exec on for.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  details = {
    scope       = "Example"
    purpose     = "Complete ECS Cluster"
    environment = "Development"
  }
}

# One key for both: ECS Exec encrypts each session with it, and CloudWatch Logs encrypts
# the log group with it. The key policy lets the account's IAM policies grant its use, and
# lets CloudWatch Logs use it for log groups in this account and Region only.
resource "aws_kms_key" "ecs_exec" {
  description         = "ECS Exec sessions and logs for the example-complete cluster"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
    ]
  })
}

module "ecs_cluster" {
  source = "../../"

  details = local.details
  name    = "example-complete"

  container_insights = "enhanced"

  execute_command = {
    logging    = "OVERRIDE"
    kms_key_id = aws_kms_key.ecs_exec.arn
    log_group = {
      retention_in_days = 90
      kms_key_id        = aws_kms_key.ecs_exec.arn
    }
  }

  default_capacity_provider_strategy = [
    { capacity_provider = "FARGATE", base = 1, weight = 1 },
    { capacity_provider = "FARGATE_SPOT", weight = 3 },
  ]
}

# What a task's containers need for ECS Exec: the Session Manager channels, writing to the
# log group, and decrypting the session with the key.
data "aws_iam_policy_document" "ecs_exec" {
  statement {
    sid = "SessionManagerChannels"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "FindLogGroup"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
    resources = ["${module.ecs_cluster.metadata.cloudwatch_log_group.arn}:*"]
  }

  statement {
    sid       = "DecryptSession"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.ecs_exec.arn]
  }
}

resource "aws_iam_policy" "ecs_exec" {
  name        = "example-complete-ecs-exec"
  description = "ECS Exec for tasks in the example-complete cluster"
  policy      = data.aws_iam_policy_document.ecs_exec.json
  tags        = module.ecs_cluster.metadata.details.tags
}

output "cluster" {
  description = "The cluster's name and ARN, the ECS Exec log group, and the IAM policy to attach to task roles"
  value = {
    name            = module.ecs_cluster.metadata.ecs_cluster.name
    arn             = module.ecs_cluster.metadata.ecs_cluster.arn
    log_group       = module.ecs_cluster.metadata.cloudwatch_log_group.name
    ecs_exec_policy = aws_iam_policy.ecs_exec.arn
  }
}
