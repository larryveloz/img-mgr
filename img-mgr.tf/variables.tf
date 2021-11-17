# Variable definitions
variable "region" {}

variable "bucket" {}

variable "environment" {
  description = "The Deployment environment"
}

variable "CPUHighPolicy" {
  description = "CPU Alarm High Threshold"
  type        = string
  default     = "50"
}

variable "CPULowPolicy" {
  description = "CPU Alarm Low Threshold"
  type        = string
  default     = "15"
}
