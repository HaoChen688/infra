variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "myapp"
}

variable "instance_type" {
  type    = string
  default = "t1.micro"
}

variable "ami_id" {
  type    = string
  default = ""
}

variable "key_name" {
  type = string
}

variable "admin_cidrs" {
  type        = list(string)
  description = "SSH 允许的 CIDR 列表"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "startup_s3_bucket" {
  type = string
}

variable "startup_s3_key" {
  type    = string
  default = "scripts/startup.sh"
}