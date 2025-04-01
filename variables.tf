variable "cloudwatch_retention" {
  description = "Cloudwatch Retention Period (in days)"
  type        = number
  default     = 30
}

variable "container_insights_enabled" {
  description = "Container Insights Enabled"
  type        = bool
  default     = true
}

variable "logging_mode" {
  description = "The log setting to use for redirecting logs for your execute command results (NONE, DEFAULT, OVERRIDE)"
  type        = string
  default     = "DEFAULT"
}

variable "name" {
  description = "Cluster Name"
  type        = string
  validation {
    condition     = var.name != ""
    error_message = "Name not specified."
  }
}
