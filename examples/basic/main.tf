# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# One ECS cluster for Fargate tasks, with only the required inputs: Container Insights
# on, ECS Exec output logged the container's own way, and FARGATE and FARGATE_SPOT
# available to its services.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "ecs_cluster" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Basic ECS Cluster"
    environment = "Development"
  }

  name = "example-basic"
}

output "cluster" {
  description = "The cluster's name and ARN"
  value = {
    name = module.ecs_cluster.metadata.ecs_cluster.name
    arn  = module.ecs_cluster.metadata.ecs_cluster.arn
  }
}
