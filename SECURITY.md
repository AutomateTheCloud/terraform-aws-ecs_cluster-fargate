# Security

## Reporting a vulnerability

Report security problems privately, not in a public issue. On GitHub, open the repository's **Security** tab and choose **Report a vulnerability**. Only the maintainers can see the report.

Include what you found, how to reproduce it, and what an attacker could do with it.

## What counts

A security problem in this module is anything that could expose what runs in the cluster or what it logs: for example, ECS Exec sessions or their output left unencrypted when the caller asked for a key, logs sent somewhere other than the log group the caller chose, or an option the module sets without being asked to.

## Supported versions

Fixes are made to the latest release.
