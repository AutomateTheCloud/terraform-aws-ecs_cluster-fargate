# Basic ECS cluster

One ECS cluster for Fargate tasks, named `example_basic-development-use1`, in `us-east-1`, with only the required inputs:

- Container Insights on, at the standard level.
- ECS Exec output logged the way each container logs (`DEFAULT`).
- The `FARGATE` and `FARGATE_SPOT` capacity providers, with no default strategy: each service or task names its launch type or capacity provider strategy.

The output shows the cluster's name and ARN, which `aws_ecs_service` takes as `cluster`.

An empty cluster costs nothing. You pay for the Fargate tasks you run in it, and for the Container Insights metrics they produce.

## Run it

```shell
terraform init
terraform apply
```

Remove it with `terraform destroy`. ECS refuses to delete a cluster that still has services or running tasks; delete those first.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Outputs

The following outputs are exported:

#### <a name="output_cluster"></a> [cluster](#output_cluster)

Description: The cluster's name and ARN
<!-- END_TF_DOCS -->
