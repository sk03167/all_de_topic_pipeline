variable "project_name" { type = string }
variable "subnet_id" { type = string }
variable "security_group_id" { type = string }
variable "instance_type" { type = string }
variable "lake_bucket_name" { type = string }
variable "kms_key_arn" { type = string }
variable "database_secret_arn" { type = string }
variable "database_endpoint" { type = string }
variable "database_name" { type = string }
variable "database_username" { type = string }

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_iam_role" "instance" {
  name_prefix = "${var.project_name}-kafka-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "instance" {
  role = aws_iam_role.instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"], Resource = ["arn:aws:s3:::${var.lake_bucket_name}", "arn:aws:s3:::${var.lake_bucket_name}/*"] },
      { Effect = "Allow", Action = ["ssm:GetParameter"], Resource = var.database_secret_arn },
      # Amazon Linux includes SSM Agent. These allow Session Manager / Run Command
      # without opening SSH or managing a key pair for this short-lived lab host.
      { Effect = "Allow", Action = ["ssm:UpdateInstanceInformation", "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel", "ec2messages:GetEndpoint", "ec2messages:GetMessages", "ec2messages:SendReply", "ec2messages:AcknowledgeMessage", "ec2messages:DeleteMessage", "ec2messages:FailMessage"], Resource = "*" },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = var.kms_key_arn },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" }
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.project_name}-kafka-"
  role        = aws_iam_role.instance.name
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  user_data_replace_on_change = true
  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    database_endpoint   = var.database_endpoint
    database_name       = var.database_name
    database_username   = var.database_username
    database_secret_arn = var.database_secret_arn
    project_name        = var.project_name
  })
}

output "public_ip" { value = aws_instance.this.public_ip }
