# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  # The cluster name: `name` in lowercase with words joined by underscores, then the
  # environment and Region abbreviations. "Web App" in us-east-1 for Production becomes
  # web_app-production-use1.
  name_abbr    = lower(replace(replace(var.name, "/[^0-9A-Za-z]/", " "), "/\\s{1,}/", "_"))
  cluster_name = "${local.name_abbr}-${local.environment.abbr}-${local.aws.region.abbr}"

  # The execute command log group exists only when ECS Exec output goes to it.
  create_log_group = var.execute_command.logging == "OVERRIDE"
}
