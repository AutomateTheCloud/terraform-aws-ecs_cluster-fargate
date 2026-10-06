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
  details = { scope = "Test", purpose = "Region", environment = "test" }
  name    = "app"
}

# The module uses the default aws provider: no providers block is needed.
run "provider_region_by_default" {
  command = plan
  assert {
    condition     = output.metadata.aws.region.name == "us-east-1" && aws_ecs_cluster.this.name == "app-test-use1"
    error_message = "Expected the provider's Region."
  }
}

run "region_reaches_every_resource" {
  command = apply
  variables {
    region          = "us-west-2"
    execute_command = { logging = "OVERRIDE" }
  }
  assert {
    condition = alltrue([
      aws_ecs_cluster.this.region == "us-west-2",
      aws_ecs_cluster_capacity_providers.this.region == "us-west-2",
      aws_cloudwatch_log_group.this[0].region == "us-west-2",
      aws_ecs_cluster.this.name == "app-test-usw2",
      output.metadata.ecs_cluster.region == "us-west-2",
      output.metadata.aws.region.name == "us-west-2",
      output.metadata.aws.region.abbr == "usw2",
    ])
    error_message = "region was not passed through to every resource."
  }
}

# Regression: the old hard-coded Region table failed the plan in any Region missing
# from it, such as ap-southeast-5.
run "region_abbreviation_not_in_old_table" {
  command = plan
  variables { region = "ap-southeast-5" }
  assert {
    condition     = output.metadata.aws.region.abbr == "apse5" && aws_ecs_cluster.this.name == "app-test-apse5"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_ca_west" {
  command = plan
  variables { region = "ca-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "caw1"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_override" {
  command = plan
  variables { region = "us-gov-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "ugw1"
    error_message = "Unexpected abbreviation."
  }
}
