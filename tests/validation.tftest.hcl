# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
}

variables {
  details = { scope = "Test", purpose = "Validation", environment = "test" }
  name    = "app"
}

run "name_empty" {
  command = plan
  variables { name = "" }
  expect_failures = [var.name]
}

run "name_without_letters_or_numbers" {
  command = plan
  variables { name = "--- !" }
  expect_failures = [var.name]
}

# The environment abbreviation is used as given, so it can make the name invalid.
run "cluster_name_invalid_characters" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Validation", environment = "test", environment_abbr = "prd.1" }
  }
  expect_failures = [aws_ecs_cluster.this]
}

run "cluster_name_too_long" {
  command = plan
  variables { name = join("", [for i in range(250) : "a"]) }
  expect_failures = [aws_ecs_cluster.this]
}

run "container_insights_invalid" {
  command = plan
  variables { container_insights = "true" }
  expect_failures = [var.container_insights]
}

run "logging_invalid" {
  command = plan
  variables { execute_command = { logging = "override" } }
  expect_failures = [var.execute_command]
}

run "retention_invalid" {
  command = plan
  variables { execute_command = { logging = "OVERRIDE", log_group = { retention_in_days = 31 } } }
  expect_failures = [var.execute_command]
}

run "log_group_kms_key_not_arn" {
  command = plan
  variables { execute_command = { logging = "OVERRIDE", log_group = { kms_key_id = "alias/logs" } } }
  expect_failures = [var.execute_command]
}

run "strategy_unknown_capacity_provider" {
  command = plan
  variables { default_capacity_provider_strategy = [{ capacity_provider = "EC2", weight = 1 }] }
  expect_failures = [var.default_capacity_provider_strategy]
}

run "strategy_duplicate_capacity_provider" {
  command = plan
  variables {
    default_capacity_provider_strategy = [
      { capacity_provider = "FARGATE", weight = 1 },
      { capacity_provider = "FARGATE", weight = 2 },
    ]
  }
  expect_failures = [var.default_capacity_provider_strategy]
}

run "strategy_weight_too_high" {
  command = plan
  variables { default_capacity_provider_strategy = [{ capacity_provider = "FARGATE", weight = 1001 }] }
  expect_failures = [var.default_capacity_provider_strategy]
}

run "strategy_weight_fraction" {
  command = plan
  variables { default_capacity_provider_strategy = [{ capacity_provider = "FARGATE", weight = 1.5 }] }
  expect_failures = [var.default_capacity_provider_strategy]
}

run "strategy_base_too_high" {
  command = plan
  variables { default_capacity_provider_strategy = [{ capacity_provider = "FARGATE", base = 100001, weight = 1 }] }
  expect_failures = [var.default_capacity_provider_strategy]
}

run "strategy_two_bases" {
  command = plan
  variables {
    default_capacity_provider_strategy = [
      { capacity_provider = "FARGATE", base = 1, weight = 1 },
      { capacity_provider = "FARGATE_SPOT", base = 1, weight = 1 },
    ]
  }
  expect_failures = [var.default_capacity_provider_strategy]
}

run "details_scope_empty" {
  command = plan
  variables { details = { scope = " ", purpose = "Validation", environment = "test" } }
  expect_failures = [var.details]
}

run "details_purpose_empty" {
  command = plan
  variables { details = { scope = "Test", purpose = "", environment = "test" } }
  expect_failures = [var.details]
}

run "details_environment_empty" {
  command = plan
  variables { details = { scope = "Test", purpose = "Validation", environment = "" } }
  expect_failures = [var.details]
}

# The limits AWS accepts (probed with the AWS CLI) pass.
run "strategy_limits_accepted" {
  command = plan
  variables {
    default_capacity_provider_strategy = [
      { capacity_provider = "FARGATE", base = 100000, weight = 1000 },
      { capacity_provider = "FARGATE_SPOT", base = 0, weight = 0 },
    ]
  }
}
