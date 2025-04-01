resource "aws_ecs_cluster" "this" {
  name = "${local.ecs_cluster_name}-${local.environment.abbr}-${local.aws.region.abbr}"

  configuration {
    execute_command_configuration {
      logging = var.logging_mode

      dynamic "log_configuration" {
        for_each = try(var.logging_mode, "") == "OVERRIDE" ? [1] : []
        content {
          cloud_watch_encryption_enabled = true
          cloud_watch_log_group_name     = try(aws_cloudwatch_log_group.this[0].name, null)
        }
      }
    }
  }
  setting {
    name  = "containerInsights"
    value = try(var.container_insights_enabled, false) == true ? "enabled" : "disabled"
  }
  tags = merge(
    local.tags,
    tomap({
      "Name" = "${local.ecs_cluster_name}-${local.environment.abbr}-${local.aws.region.abbr}"
    })
  )
  provider = aws.this
}
