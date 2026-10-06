# Terraform module for Amazon ECS clusters on AWS Fargate

Creates an Amazon Elastic Container Service (ECS) cluster for tasks that run on AWS Fargate, where AWS runs the servers and you pay for each task's CPU and memory. The cluster has the `FARGATE` and `FARGATE_SPOT` capacity providers, Container Insights metrics, and the settings for ECS Exec, which opens a shell in a running container.

The module creates the cluster only. Services, task definitions, IAM roles and the network they run in are created separately, for example with `aws_ecs_service` and `aws_ecs_task_definition`, and refer to the cluster through the `metadata` output.

## What it configures

| Setting | Default | Input |
|---|---|---|
| Cluster name | `name` in lowercase with words joined by underscores, plus the environment and Region abbreviations: `web_app-production-use1` | `name`, `details` |
| Capacity providers | `FARGATE` and `FARGATE_SPOT`, always | Not an input |
| Default capacity provider strategy | None: each service or task names its launch type or strategy | `default_capacity_provider_strategy` |
| Container Insights | `enabled` (standard metrics) | `container_insights` |
| ECS Exec command logging | `DEFAULT`: to each container's own `awslogs` configuration | `execute_command.logging` |
| ECS Exec session encryption | TLS only, no KMS key | `execute_command.kms_key_id` |
| ECS Exec log group | None. With `OVERRIDE`: `/ecs_cluster/<cluster name>`, kept 30 days, no KMS key | `execute_command.log_group` |
| Region | The AWS provider's Region | `region` |
| Tags | `Scope`, `Purpose`, `Environment`, `Name` (the cluster's name), and any `additional_tags` | `details` |

## Usage

```hcl
module "ecs_cluster" {
  source  = "AutomateTheCloud/ecs_cluster-fargate/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Web App"
    environment = "Production"
  }

  name = "web-app"
}

resource "aws_ecs_service" "web" {
  name            = "web"
  cluster         = module.ecs_cluster.metadata.ecs_cluster.arn
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.web.id]
  }
}
```

`details` and `name` are the required inputs. `details` sets the `Scope`, `Purpose` and `Environment` tags. `name`, with the environment and Region abbreviations from `details`, makes the cluster's name: here `web_app-production-use1`.

The module uses your default `aws` provider and creates the cluster in that provider's Region. To create it somewhere else without configuring another provider, set `region`:

```hcl
module "ecs_cluster_us_west_2" {
  source  = "AutomateTheCloud/ecs_cluster-fargate/aws"
  version = "~> 1.0"

  region  = "us-west-2"
  details = { scope = "Automate the Cloud", purpose = "Web App", environment = "Production" }
  name    = "web-app"
}
```

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the cluster belongs to, what it is for, and which environment it is in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Web App"            # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at a cluster in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the cluster, its services, their load balancer and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Web App"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "ecs_cluster" {
  source  = "AutomateTheCloud/ecs_cluster-fargate/aws"
  version = "~> 1.0"

  details = local.details
  name    = "web-app"
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Web App` becomes `web_app`), and `machine`, lowercase letters and numbers only (`webapp`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`. This module uses the environment's short form in the cluster's name.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.ecs_cluster.metadata.ecs_cluster.arn` for the cluster's ARN, or `module.ecs_cluster.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration. Run it with `terraform init` and `terraform apply`.

- [Basic ECS cluster](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/tree/main/examples/basic): a cluster with only the required inputs.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/tree/main/examples/complete): ECS Exec with a KMS key and an encrypted log group, enhanced Container Insights, a default strategy that mixes Fargate and Fargate Spot, and the IAM policy task roles need for ECS Exec.

## Things to know

### Changing the name replaces the cluster

ECS cannot rename a cluster. Changing `name` or `region`, or anything in `details` that changes the environment's short form, deletes the cluster and creates a new one. Every `aws_ecs_service` in the same configuration that refers to the cluster is replaced with it, so its tasks stop and start again in the new cluster. Changing only the tags, `container_insights`, `execute_command` or `default_capacity_provider_strategy` updates the cluster in place.

ECS refuses to delete a cluster that still has services, such as ones created in another configuration or by hand. Terraform then removes the old cluster's capacity providers first, retries the delete for 10 minutes, and fails with `ClusterContainsServicesException`, leaving the old cluster without capacity providers. Move or delete those services first; once they are gone, `terraform apply` finishes the change.

### Fargate and Fargate Spot

Both capacity providers are always attached. A service or task picks one with `launch_type = "FARGATE"`, or with a `capacity_provider_strategy` of its own. One that names neither uses `default_capacity_provider_strategy`; without a default, it fails with "No Container Instances were found in your cluster". Fargate Spot runs tasks on spare capacity at a discount, and AWS can stop them with two minutes' warning, so use it for work that can be interrupted. See [Fargate capacity providers](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-capacity-providers.html).

The module manages the cluster's capacity providers with an `aws_ecs_cluster_capacity_providers` resource. Do not attach capacity providers to the same cluster anywhere else: two such resources overwrite each other. EC2 and Auto Scaling group capacity providers are not supported.

Give every `aws_ecs_service` that Terraform manages its own `launch_type` or `capacity_provider_strategy`, even when the cluster has a default strategy. When a service names neither, ECS copies the cluster's default strategy into the service, and the AWS provider then tries to remove it on every plan, which fails with "force_new_deployment should be true when capacity_provider_strategy is being updated". The default strategy is for tasks and services started without one, such as with `aws ecs run-task` or in the console.

### ECS Exec

ECS Exec runs a command, or opens a shell, in a running container: `aws ecs execute-command --cluster <name> --task <task ID> --container <container> --interactive --command "/bin/sh"`. It needs the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) on your computer, and three things outside this module:

- `enable_execute_command = true` on the service or task.
- A task role that allows the Session Manager channels (`ssmmessages:CreateControlChannel`, `CreateDataChannel`, `OpenControlChannel`, `OpenDataChannel`) and, with `logging = "OVERRIDE"`, writing to the log group (`logs:CreateLogStream`, `logs:DescribeLogStreams`, `logs:PutLogEvents`). With `execute_command.log_group.kms_key_id`, it also needs `logs:DescribeLogGroups`, and with `execute_command.kms_key_id`, `kms:Decrypt` on that key. The [complete example](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/tree/main/examples/complete) has the policy.
- A network path from the task to Systems Manager: a route to the internet, or a VPC endpoint for `ssmmessages` (and one for `logs` when logging to CloudWatch Logs, and `kms` with a KMS key).

With `logging = "OVERRIDE"`, the output of every command is written to the module's log group when the session ends. ECS Exec records the output with the `script` and `cat` programs inside the container, so an image without `script` (many minimal images, including `amazonlinux:2023`) runs commands but logs nothing. Install it, for example with `util-linux`. See [Using ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html).

When `execute_command.log_group.kms_key_id` is set, the module tells ECS Exec that the log group is encrypted, and ECS Exec checks it before each session. Without a key, the module leaves that setting off: if it were on, ECS Exec would refuse every session with "We couldn't start the session because encryption is not set up on the selected CloudWatch Logs log group". With a key, ECS Exec gives the same message when the task role lacks `logs:DescribeLogGroups`, even though the log group is encrypted.

Removing `execute_command.kms_key_id` or `execute_command.log_group.kms_key_id` updates the cluster and log group in place, but the first plan afterwards shows `metadata` changing, from `null` to `""`, although nothing in AWS changes: the provider reads the empty value back only on the next refresh. Applying that plan, which changes no resources, clears it.

### Container Insights

Container Insights is on by default, at the standard level, because it is the main way to see how much CPU and memory a cluster's tasks use. It is billed as CloudWatch metrics and log data, and the cost grows with the number of services, tasks and containers. `enhanced` adds metrics per task and container, and costs more; `disabled` turns it off. See [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/).

### The log group is deleted with the cluster

With `logging = "OVERRIDE"`, the log group belongs to the module: `terraform destroy`, or switching `logging` away from `OVERRIDE`, deletes it and every command log in it. Changing the cluster's name moves logging to a new log group under the new name, and deletes the old one.

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web App`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web App` becomes `web_app`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_name"></a> [name](#input_name)

Description: The cluster's name. The module converts it to lowercase, with each run of characters other than letters and numbers turned into one underscore, and adds the environment and Region abbreviations from `details`: `Web App` for `environment = "Production"` in us-east-1 becomes `web_app-production-use1`. The whole name can be up to 255 characters. Changing it, or anything in `details` that changes the abbreviations, replaces the cluster (see the README).

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_container_insights"></a> [container_insights](#input_container_insights)

Description: CloudWatch Container Insights for the cluster, which collects CPU, memory, network and storage metrics for its services and tasks:

- `enabled` (the default) - Metrics per cluster, service and task definition.
- `enhanced` - Also per task and container, with more detail. It sends more metrics, and costs more.
- `disabled` - No Container Insights metrics. ECS still sends the free basic service metrics.

Container Insights is billed as CloudWatch custom metrics and log ingestion; see [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/). Changing it updates the cluster in place.

Type: `string`

Default: `"enabled"`

#### <a name="input_default_capacity_provider_strategy"></a> [default_capacity_provider_strategy](#input_default_capacity_provider_strategy)

Description: How services and tasks that name no launch type and no capacity provider strategy of their own are spread between `FARGATE` and `FARGATE_SPOT`. Both capacity providers are always available to the cluster; this only sets the default. An empty list (the default) sets no default strategy: each service or task must then give a launch type or a strategy.

Each item takes:

- `capacity_provider` - (Required) `FARGATE` or `FARGATE_SPOT`, each at most once.
- `weight` - (Optional) The share of tasks, relative to the other item, placed on this capacity provider after `base` is met. 0 to 1000. Defaults to `0`.
- `base` - (Optional) The number of tasks always placed on this capacity provider first. 0 to 100000, and more than 0 on at most one item. Defaults to `0`.

For example, `[{ capacity_provider = "FARGATE", base = 1, weight = 1 }, { capacity_provider = "FARGATE_SPOT", weight = 3 }]` runs the first task on Fargate, then three of every four more tasks on Fargate Spot. Fargate Spot tasks can be stopped with two minutes' notice when AWS needs the capacity back.

Type:

```hcl
list(object({
    capacity_provider = string
    weight            = optional(number, 0)
    base              = optional(number, 0)
  }))
```

Default: `[]`

#### <a name="input_execute_command"></a> [execute_command](#input_execute_command)

Description: Settings for [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html), which runs commands, or a shell, inside a running container with `aws ecs execute-command`. ECS Exec is turned on per service or task (`enable_execute_command`); these settings say where the commands' output is logged and how the session is encrypted.

- `logging` - (Optional) Where command output is logged. Defaults to `DEFAULT`.

  - `DEFAULT` - To the container's `awslogs` log configuration, if it has one; otherwise nowhere.
  - `OVERRIDE` - To a CloudWatch Logs log group the module creates, named `/ecs_cluster/<cluster name>`, set with `log_group`.
  - `NONE` - Not logged.

- `kms_key_id` - (Optional) The ID or ARN of a KMS key that encrypts the session between your computer and the container, on top of TLS. The task role then needs `kms:Decrypt` on it. Defaults to none.
- `log_group` - (Optional) The log group created when `logging` is `OVERRIDE`. Ignored otherwise.

  - `retention_in_days` - (Optional) How long the log group keeps output: 0 (forever), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653. Defaults to `30`.
  - `kms_key_id` - (Optional) The ARN of a KMS key to encrypt the log group with. Its key policy must let the CloudWatch Logs service principal of the Region use it. When it is set, the cluster also tells ECS Exec that the log group is encrypted; ECS Exec checks this, and the task role needs `logs:DescribeLogGroups`. Defaults to no key: CloudWatch Logs encrypts the data with its own keys.

Type:

```hcl
object({
    logging    = optional(string, "DEFAULT")
    kms_key_id = optional(string)
    log_group = optional(object({
      retention_in_days = optional(number, 30)
      kms_key_id        = optional(string)
    }), {})
  })
```

Default: `{}`

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the cluster in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. Changing it replaces the cluster.

Type: `string`

Default: `null`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

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
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
