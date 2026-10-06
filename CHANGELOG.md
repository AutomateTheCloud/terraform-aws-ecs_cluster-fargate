# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.1] - 2026-10-06

### Changed

- The copyright year in `NOTICE` and the file headers is now 2026, the year the module was rebuilt and released as 1.0.0.
- `CLAUDE.md`, the working rules shared by every Automate the Cloud module, adds the lessons learned while rebuilding the modules.

## [1.0.0] - 2026-10-05

Initial release.

### Added

- An Amazon ECS cluster for AWS Fargate tasks, named from `name` and the environment and Region abbreviations, with the `FARGATE` and `FARGATE_SPOT` capacity providers.
- `default_capacity_provider_strategy`, to spread services and tasks that name no launch type between Fargate and Fargate Spot.
- `container_insights`: `enabled` (the default), `enhanced` or `disabled`.
- `execute_command`, for ECS Exec: where command output is logged, a KMS key for the sessions, and a CloudWatch Logs log group the module creates, optionally encrypted with a KMS key.
- Checks at plan time for the values ECS and CloudWatch Logs reject.
- `Scope`, `Purpose` and `Environment` tags from the `details` input.
- `region`, to create the cluster in a Region other than the provider's.
- A `metadata` output with the cluster's name and ARN, and everything else the module created.
- Offline tests, and examples for a cluster with the defaults and one with every option.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-ecs_cluster-fargate/releases/tag/v1.0.0
