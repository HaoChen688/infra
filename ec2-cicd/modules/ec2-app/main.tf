terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "al2" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2[0].id
  subnet = data.aws_subnets.default.ids[0]
}

# ---------- IAM ----------
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project}-${var.env}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "s3_read" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.startup_s3_bucket}/${var.startup_s3_key}"]
  }
}

resource "aws_iam_role_policy" "s3_read" {
  name   = "read-startup"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.s3_read.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.env}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ---------- 安全组（声明式：仅保留 admin_cidrs 列表）----------
resource "aws_security_group" "app" {
  name        = "${var.project}-${var.env}-sg"
  description = "SG for ${var.project} ${var.env}"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = var.admin_cidrs
    content {
      description = "SSH from ${ingress.value}"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  ingress {
    description = "App port (internal / ALB)"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg"
    env  = var.env
  }
}

# ---------- user_data（bootstrap，装 systemd unit 并首次执行）----------
locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    yum update -y || true
    yum install -y curl awscli

    cat >/usr/local/bin/run-startup.sh <<'WRAP'
    #!/bin/bash
    set -euo pipefail
    BUCKET="__BUCKET__"
    KEY="__KEY__"
    ENV="__ENV__"
    PROJECT="__PROJECT__"
    REGION="__REGION__"
    LOCAL=/usr/local/bin/startup.sh

    aws s3 cp "s3://$BUCKET/$KEY" "$LOCAL" --region "$REGION"
    chmod +x "$LOCAL"
    ENV_NAME="$ENV" PROJECT="$PROJECT" "$LOCAL"
    WRAP
    chmod +x /usr/local/bin/run-startup.sh

    cat >/etc/systemd/system/startup.service <<'UNIT'
    [Unit]
    Description=Run idempotent startup script from S3
    After=network-online.target cloud-init.service
    Wants=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/run-startup.sh
    RemainAfterExit=no

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable startup.service
    systemctl start startup.service || true
  EOT

  user_data_rendered = replace(
    replace(
      replace(
        replace(
          replace(local.user_data, "__BUCKET__", var.startup_s3_bucket),
          "__KEY__", var.startup_s3_key
        ),
        "__ENV__", var.env
      ),
      "__PROJECT__", var.project
    ),
    "__REGION__", var.region
  )
}

# ---------- EC2 ----------
resource "aws_instance" "app" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.subnet
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = local.user_data_rendered

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp2"
  }

  tags = {
    Name  = "${var.project}-${var.env}"
    env   = var.env
    owner = "platform"
  }
}