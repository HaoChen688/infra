variable "project" {
  type = string
}

variable "env" {
  type        = string
  description = "dev | prod"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t1.micro"
}

variable "ami_id" {
  type        = string
  description = "留空则自动取 us-east-1 最新 Amazon Linux 2"
  default     = ""
}

variable "key_name" {
  type = string
}

variable "admin_cidrs" {
  type        = list(string)
  description = "允许 SSH 的源 CIDR 列表（不写死，由 tfvars 或 CI 注入）"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "startup_s3_bucket" {
  type = string
}

variable "startup_s3_key" {
  type    = string
  default = "scripts/startup.sh"
}