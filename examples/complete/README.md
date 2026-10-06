# Complete ECS cluster

An ECS cluster for Fargate tasks, named `example_complete-development-use1`, in `us-east-1`, with every option the module has:

- **ECS Exec** sessions encrypted with a customer managed KMS key, and the output of every command logged to the log group `/ecs_cluster/example_complete-development-use1`, kept for 90 days and encrypted with the same key. The key policy lets CloudWatch Logs use the key only for log groups in this account and Region.
- **Enhanced Container Insights**, with metrics per task and container.
- **A default capacity provider strategy**: a service that names no launch type runs its first task on Fargate, then three of every four more tasks on Fargate Spot.
- **An IAM policy**, `example-complete-ecs-exec`, with what a task role needs for ECS Exec on this cluster: the Session Manager channels, writing to the log group, and decrypting the session with the key. Attach it to the task role of each service you turn ECS Exec on for (`enable_execute_command = true` in `aws_ecs_service`).

The output shows the cluster's name and ARN, the log group, and the policy's ARN.

The KMS key costs $1 a month, and enhanced Container Insights costs more than the standard level. See [AWS KMS pricing](https://aws.amazon.com/kms/pricing/) and [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/).

## Run it

```shell
terraform init
terraform apply
```

Then open a shell in a running container of a service that has ECS Exec turned on and the policy attached to its task role. You need the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI:

```shell
aws ecs execute-command --cluster example_complete-development-use1 \
  --task <task ID> --container <container name> --interactive --command "/bin/sh"
```

Remove it with `terraform destroy`. The log group is deleted with the cluster, and its logs with it. The KMS key is scheduled for deletion after 30 days.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Outputs

The following outputs are exported:

#### <a name="output_cluster"></a> [cluster](#output_cluster)

Description: The cluster's name and ARN, the ECS Exec log group, and the IAM policy to attach to task roles
<!-- END_TF_DOCS -->
