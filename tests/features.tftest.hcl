# Copyright 2026 Automate the Cloud Inc.
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
  details = { scope = "Test", purpose = "Features", environment = "test" }
  name    = "app"
}

# Regression: the old module set cloud_watch_encryption_enabled = true on a log group
# with no KMS key, a combination ECS Exec refuses. Without a key it is now false.
run "override_without_kms_key" {
  command = plan
  variables {
    execute_command = { logging = "OVERRIDE" }
  }

  assert {
    condition = alltrue([
      aws_cloudwatch_log_group.this[0].name == "/ecs_cluster/app-test-use1",
      aws_cloudwatch_log_group.this[0].retention_in_days == 30,
      aws_cloudwatch_log_group.this[0].kms_key_id == null,
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].logging == "OVERRIDE",
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].cloud_watch_log_group_name == "/ecs_cluster/app-test-use1",
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].cloud_watch_encryption_enabled == false,
    ])
    error_message = "Unexpected OVERRIDE configuration without a KMS key."
  }
}

run "override_with_kms_key" {
  command = plan
  variables {
    execute_command = {
      logging    = "OVERRIDE"
      kms_key_id = "arn:aws:kms:us-east-1:111111111111:key/1234abcd-12ab-34cd-56ef-1234567890ab"
      log_group = {
        retention_in_days = 365
        kms_key_id        = "arn:aws:kms:us-east-1:111111111111:key/abcd1234-ab12-cd34-ef56-abcdef123456"
      }
    }
  }

  assert {
    condition = alltrue([
      aws_cloudwatch_log_group.this[0].retention_in_days == 365,
      aws_cloudwatch_log_group.this[0].kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/abcd1234-ab12-cd34-ef56-abcdef123456",
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/1234abcd-12ab-34cd-56ef-1234567890ab",
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration[0].cloud_watch_encryption_enabled == true,
    ])
    error_message = "Unexpected OVERRIDE configuration with KMS keys."
  }
}

run "override_apply" {
  command = apply
  variables {
    execute_command = { logging = "OVERRIDE" }
  }

  assert {
    condition = alltrue([
      output.metadata.cloudwatch_log_group.name == "/ecs_cluster/app-test-use1",
      output.metadata.cloudwatch_log_group.retention_in_days == 30,
    ])
    error_message = "The log group is missing from metadata."
  }
}

# The log group settings are ignored unless logging is OVERRIDE.
run "log_group_ignored_without_override" {
  command = plan
  variables {
    execute_command = {
      logging   = "NONE"
      log_group = { retention_in_days = 7 }
    }
  }

  assert {
    condition = alltrue([
      length(aws_cloudwatch_log_group.this) == 0,
      aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].logging == "NONE",
      length(aws_ecs_cluster.this.configuration[0].execute_command_configuration[0].log_configuration) == 0,
    ])
    error_message = "A log group was configured without OVERRIDE."
  }
}

run "container_insights" {
  command = plan
  variables { container_insights = "enhanced" }

  assert {
    condition     = one(aws_ecs_cluster.this.setting).value == "enhanced"
    error_message = "container_insights was not passed through."
  }
}

run "container_insights_disabled" {
  command = plan
  variables { container_insights = "disabled" }

  assert {
    condition     = one(aws_ecs_cluster.this.setting).value == "disabled"
    error_message = "container_insights was not passed through."
  }
}

run "default_capacity_provider_strategy" {
  command = plan
  variables {
    default_capacity_provider_strategy = [
      { capacity_provider = "FARGATE", base = 1, weight = 1 },
      { capacity_provider = "FARGATE_SPOT", weight = 3 },
    ]
  }

  assert {
    condition = toset([for s in aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy : "${s.capacity_provider}|${s.base}|${s.weight}"]) == toset([
      "FARGATE|1|1",
      "FARGATE_SPOT|0|3",
    ])
    error_message = "Unexpected default capacity provider strategy."
  }
}

# The name is converted to lowercase with each run of other characters turned into an
# underscore.
run "name_conversion" {
  command = plan
  variables { name = "  My App (v2)!! " }

  assert {
    condition     = aws_ecs_cluster.this.name == "_my_app_v2_-test-use1"
    error_message = "Unexpected name: ${aws_ecs_cluster.this.name}."
  }
}

run "environment_abbr" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Features", environment = "Production", environment_abbr = "prd" }
  }

  assert {
    condition     = aws_ecs_cluster.this.name == "app-prd-use1"
    error_message = "Unexpected name: ${aws_ecs_cluster.this.name}."
  }
}

# Regression: an empty environment_abbr gave the name app--use1. It now counts as unset.
run "empty_environment_abbr" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Features", environment = "Production", environment_abbr = "" }
  }

  assert {
    condition     = aws_ecs_cluster.this.name == "app-production-use1"
    error_message = "Unexpected name: ${aws_ecs_cluster.this.name}."
  }
}

run "additional_tags" {
  command = plan
  variables {
    details         = { scope = "Test", purpose = "Features", environment = "test", additional_tags = { CostCenter = "1234" } }
    execute_command = { logging = "OVERRIDE" }
  }

  assert {
    condition = alltrue([
      aws_ecs_cluster.this.tags["CostCenter"] == "1234",
      aws_cloudwatch_log_group.this[0].tags["CostCenter"] == "1234",
      aws_cloudwatch_log_group.this[0].tags["Scope"] == "Test",
    ])
    error_message = "additional_tags did not reach every resource."
  }
}
