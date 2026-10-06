# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `ecs_cluster` - The cluster:

      - `name` - The cluster's name, such as `web_app-production-use1`. `aws_ecs_service` and `aws ecs run-task` accept it as `cluster`.
      - `arn` - The cluster's ARN, for IAM policies and `aws_ecs_service`. `id` is the same value.
      - `configuration` - The ECS Exec settings: `execute_command_configuration` with `logging`, `kms_key_id` and `log_configuration`.
      - `setting` - The `containerInsights` setting.
      - `service_connect_defaults` - A setting the module does not use. Empty.
      - `region`, `tags` and `tags_all`.

    - `ecs_cluster_capacity_providers` - The capacity providers attached to the cluster: `capacity_providers` (always `FARGATE` and `FARGATE_SPOT`), `default_capacity_provider_strategy`, `cluster_name`, `id` (the cluster's name) and `region`.
    - `cloudwatch_log_group` - The log group for ECS Exec output, or `null` when `execute_command.logging` is not `OVERRIDE`: `name`, `arn`, `id` (the name), `kms_key_id`, `retention_in_days`, `log_group_class`, `region`, `tags` and `tags_all`. `name_prefix` and `skip_destroy` are settings the module does not use.
  EOT
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    # One entry per resource; null when the resource is not created.
    ecs_cluster                    = local.output_resources.ecs_cluster
    ecs_cluster_capacity_providers = local.output_resources.ecs_cluster_capacity_providers
    cloudwatch_log_group           = local.output_resources.cloudwatch_log_group
  }
}

locals {
  # Each resource's attributes are listed one by one. Referencing a whole resource
  # would also reference any attribute the provider deprecates later, and every
  # caller's plan would print deprecation warnings.
  output_resources = {
    ecs_cluster = {
      arn                      = aws_ecs_cluster.this.arn
      configuration            = aws_ecs_cluster.this.configuration
      id                       = aws_ecs_cluster.this.id
      name                     = aws_ecs_cluster.this.name
      region                   = aws_ecs_cluster.this.region
      service_connect_defaults = aws_ecs_cluster.this.service_connect_defaults
      setting                  = aws_ecs_cluster.this.setting
      tags                     = aws_ecs_cluster.this.tags
      tags_all                 = aws_ecs_cluster.this.tags_all
    }

    ecs_cluster_capacity_providers = {
      capacity_providers                 = aws_ecs_cluster_capacity_providers.this.capacity_providers
      cluster_name                       = aws_ecs_cluster_capacity_providers.this.cluster_name
      default_capacity_provider_strategy = aws_ecs_cluster_capacity_providers.this.default_capacity_provider_strategy
      id                                 = aws_ecs_cluster_capacity_providers.this.id
      region                             = aws_ecs_cluster_capacity_providers.this.region
    }

    # deletion_protection_enabled is left out: it is not in AWS provider 6.0.0.
    cloudwatch_log_group = length(aws_cloudwatch_log_group.this) == 0 ? null : {
      arn               = aws_cloudwatch_log_group.this[0].arn
      id                = aws_cloudwatch_log_group.this[0].id
      kms_key_id        = aws_cloudwatch_log_group.this[0].kms_key_id
      log_group_class   = aws_cloudwatch_log_group.this[0].log_group_class
      name              = aws_cloudwatch_log_group.this[0].name
      name_prefix       = aws_cloudwatch_log_group.this[0].name_prefix
      region            = aws_cloudwatch_log_group.this[0].region
      retention_in_days = aws_cloudwatch_log_group.this[0].retention_in_days
      skip_destroy      = aws_cloudwatch_log_group.this[0].skip_destroy
      tags              = aws_cloudwatch_log_group.this[0].tags
      tags_all          = aws_cloudwatch_log_group.this[0].tags_all
    }
  }
}
