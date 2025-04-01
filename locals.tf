locals {
  ecs_cluster_name = lower(replace(replace(var.name, "/[^0-9A-Za-z]/", " "), "/\\s{1,}/", "_"))
}
