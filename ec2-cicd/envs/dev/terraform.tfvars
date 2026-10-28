region            = "us-east-1"
project           = "myapp"
instance_type     = "t1.micro"
key_name          = "app-key"
admin_cidrs       = ["203.0.113.10/32"]     # 示例；CI 可生成 admin.auto.tfvars 覆盖
app_port          = 8080
startup_s3_bucket = "myapp-bootstrap-822952232701"
startup_s3_key    = "scripts/startup.sh"