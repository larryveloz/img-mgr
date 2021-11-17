# Variable definitions
variable "region" {}

variable "vpc_cidr" {
  type = string
  default = "10.132.120.0/21"
  description = "Please enter the IP range (CIDR notation) for this VPC"
}

variable "public_subnet_cidrs" {
  type = list
}

variable "private_subnet_cidrs" {
  type = list
}
