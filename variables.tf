# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "container_insights" {
  description = <<-EOT
    CloudWatch Container Insights for the cluster, which collects CPU, memory, network and storage metrics for its services and tasks:

    - `enabled` (the default) - Metrics per cluster, service and task definition.
    - `enhanced` - Also per task and container, with more detail. It sends more metrics, and costs more.
    - `disabled` - No Container Insights metrics. ECS still sends the free basic service metrics.

    Container Insights is billed as CloudWatch custom metrics and log ingestion; see [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/). Changing it updates the cluster in place.
  EOT
  type        = string
  default     = "enabled"
  nullable    = false

  validation {
    condition     = contains(["enabled", "enhanced", "disabled"], var.container_insights)
    error_message = "container_insights must be enabled, enhanced or disabled."
  }
}

variable "default_capacity_provider_strategy" {
  description = <<-EOT
    How services and tasks that name no launch type and no capacity provider strategy of their own are spread between `FARGATE` and `FARGATE_SPOT`. Both capacity providers are always available to the cluster; this only sets the default. An empty list (the default) sets no default strategy: each service or task must then give a launch type or a strategy.

    Each item takes:

    - `capacity_provider` - (Required) `FARGATE` or `FARGATE_SPOT`, each at most once.
    - `weight` - (Optional) The share of tasks, relative to the other item, placed on this capacity provider after `base` is met. 0 to 1000. Defaults to `0`.
    - `base` - (Optional) The number of tasks always placed on this capacity provider first. 0 to 100000, and more than 0 on at most one item. Defaults to `0`.

    For example, `[{ capacity_provider = "FARGATE", base = 1, weight = 1 }, { capacity_provider = "FARGATE_SPOT", weight = 3 }]` runs the first task on Fargate, then three of every four more tasks on Fargate Spot. Fargate Spot tasks can be stopped with two minutes' notice when AWS needs the capacity back.
  EOT
  type = list(object({
    capacity_provider = string
    weight            = optional(number, 0)
    base              = optional(number, 0)
  }))
  default  = []
  nullable = false

  validation {
    condition     = alltrue([for s in var.default_capacity_provider_strategy : contains(["FARGATE", "FARGATE_SPOT"], s.capacity_provider)])
    error_message = "default_capacity_provider_strategy: capacity_provider must be FARGATE or FARGATE_SPOT."
  }

  validation {
    condition     = length(distinct([for s in var.default_capacity_provider_strategy : s.capacity_provider])) == length(var.default_capacity_provider_strategy)
    error_message = "default_capacity_provider_strategy: each capacity_provider can appear only once."
  }

  validation {
    condition     = alltrue([for s in var.default_capacity_provider_strategy : s.weight != null && s.weight >= 0 && s.weight <= 1000 && floor(s.weight) == s.weight])
    error_message = "default_capacity_provider_strategy: weight must be a whole number from 0 to 1000."
  }

  validation {
    condition     = alltrue([for s in var.default_capacity_provider_strategy : s.base != null && s.base >= 0 && s.base <= 100000 && floor(s.base) == s.base])
    error_message = "default_capacity_provider_strategy: base must be a whole number from 0 to 100000."
  }

  validation {
    condition     = length([for s in var.default_capacity_provider_strategy : s if s.base != null && s.base > 0]) <= 1
    error_message = "default_capacity_provider_strategy: only one capacity provider can have a base greater than 0."
  }
}

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web App`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web App` becomes `web_app`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "execute_command" {
  description = <<-EOT
    Settings for [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html), which runs commands, or a shell, inside a running container with `aws ecs execute-command`. ECS Exec is turned on per service or task (`enable_execute_command`); these settings say where the commands' output is logged and how the session is encrypted.

    - `logging` - (Optional) Where command output is logged. Defaults to `DEFAULT`.

      - `DEFAULT` - To the container's `awslogs` log configuration, if it has one; otherwise nowhere.
      - `OVERRIDE` - To a CloudWatch Logs log group the module creates, named `/ecs_cluster/<cluster name>`, set with `log_group`.
      - `NONE` - Not logged.

    - `kms_key_id` - (Optional) The ID or ARN of a KMS key that encrypts the session between your computer and the container, on top of TLS. The task role then needs `kms:Decrypt` on it. Defaults to none.
    - `log_group` - (Optional) The log group created when `logging` is `OVERRIDE`. Ignored otherwise.

      - `retention_in_days` - (Optional) How long the log group keeps output: 0 (forever), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653. Defaults to `30`.
      - `kms_key_id` - (Optional) The ARN of a KMS key to encrypt the log group with. Its key policy must let the CloudWatch Logs service principal of the Region use it. When it is set, the cluster also tells ECS Exec that the log group is encrypted; ECS Exec checks this, and the task role needs `logs:DescribeLogGroups`. Defaults to no key: CloudWatch Logs encrypts the data with its own keys.
  EOT
  type = object({
    logging    = optional(string, "DEFAULT")
    kms_key_id = optional(string)
    log_group = optional(object({
      retention_in_days = optional(number, 30)
      kms_key_id        = optional(string)
    }), {})
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["DEFAULT", "OVERRIDE", "NONE"], var.execute_command.logging)
    error_message = "execute_command.logging must be DEFAULT, OVERRIDE or NONE."
  }

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.execute_command.log_group.retention_in_days)
    error_message = "execute_command.log_group.retention_in_days must be one of 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653."
  }

  validation {
    condition     = var.execute_command.log_group.kms_key_id == null || can(regex("^arn:[^:]+:kms:", var.execute_command.log_group.kms_key_id))
    error_message = "execute_command.log_group.kms_key_id must be a KMS key ARN: CloudWatch Logs does not accept a key ID or alias."
  }
}

variable "name" {
  description = <<-EOT
    The cluster's name. The module converts it to lowercase, with each run of characters other than letters and numbers turned into one underscore, and adds the environment and Region abbreviations from `details`: `Web App` for `environment = "Production"` in us-east-1 becomes `web_app-production-use1`. The whole name can be up to 255 characters. Changing it, or anything in `details` that changes the abbreviations, replaces the cluster (see the README).
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("[0-9A-Za-z]", var.name))
    error_message = "name must contain at least one letter or number."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the cluster in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. Changing it replaces the cluster.
  EOT
  type        = string
  default     = null
}
