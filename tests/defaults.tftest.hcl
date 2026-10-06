# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_ecs_cluster" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:111111111111:cluster/web_app-production-use1"
    }
  }
}

variables {
  details = { scope = "Test", purpose = "Defaults", environment = "Production" }
  name    = "Web App"
}

# With only the required inputs: Container Insights on, ECS Exec output logged the
# container's own way, both Fargate capacity providers, no default strategy, and no
# log group.
run "defaults_plan" {
  command = plan

  assert {
    condition = alltrue([
      aws_ecs_cluster.this.name == "web_app-production-use1",
      one(aws_ecs_cluster.this.setting).name == "containerInsights",
      one(aws_ecs_cluster.this.setting).value == "enabled",
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].logging == "DEFAULT",
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].kms_key_id == null,
      length(aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration) == 0,
      length(aws_cloudwatch_log_group.this) == 0,
    ])
    error_message = "Unexpected cluster configuration with only the required inputs."
  }

  assert {
    condition = alltrue([
      aws_ecs_cluster_capacity_providers.this.cluster_name == "web_app-production-use1",
      aws_ecs_cluster_capacity_providers.this.capacity_providers == toset(["FARGATE", "FARGATE_SPOT"]),
      length(aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy) == 0,
    ])
    error_message = "Unexpected capacity providers with only the required inputs."
  }

  assert {
    condition = alltrue([
      aws_ecs_cluster.this.tags == tomap({ Scope = "Test", Purpose = "Defaults", Environment = "Production", Name = "web_app-production-use1" }),
    ])
    error_message = "Unexpected tags."
  }
}

run "defaults_apply" {
  command = apply

  assert {
    condition = alltrue([
      output.metadata.ecs_cluster.name == "web_app-production-use1",
      output.metadata.ecs_cluster.arn == "arn:aws:ecs:us-east-1:111111111111:cluster/web_app-production-use1",
      join(",", sort(output.metadata.ecs_cluster_capacity_providers.capacity_providers)) == "FARGATE,FARGATE_SPOT",
      output.metadata.cloudwatch_log_group == null,
      output.metadata.aws.region.name == "us-east-1",
      output.metadata.aws.region.abbr == "use1",
      output.metadata.aws.account.id == "111111111111",
      output.metadata.details.environment.abbr == "production",
      output.metadata.details.tags["Scope"] == "Test",
    ])
    error_message = "Unexpected metadata output."
  }
}
