resource "aws_cloudwatch_log_group" "this" {
  count             = try(var.logging_mode, "") == "OVERRIDE" ? 1 : 0
  name              = "/ecs_cluster/${local.ecs_cluster_name}-${local.environment.abbr}-${local.aws.region.abbr}"
  retention_in_days = var.cloudwatch_retention
  tags              = local.tags
  provider          = aws.this
}
