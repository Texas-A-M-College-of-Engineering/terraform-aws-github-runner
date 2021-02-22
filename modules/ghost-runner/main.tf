data "aws_ami" "latest_ghost_ami" {
  owners        = [ "amazon" ]
  most_recent   = true

  filter {
    name    = "name"
    values  = [var.ghost_ami_filter]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
}

resource "aws_iam_instance_profile" "ghost_ec2_profile" {
  name = "ghost_${var.environment}_ec2_profile"
  role = var.ghost_ec2_role
}

module "ec2_ghost_runner" {
  source                  = "terraform-aws-modules/ec2-instance/aws"
  version                 = "~> 2.0"

  name                    = "ghost-${var.environment}"
  instance_count          = 1

  ami                     = data.aws_ami.latest_ghost_ami.id
  instance_type           = var.ghost_instance_type
  iam_instance_profile    = aws_iam_instance_profile.ghost_ec2_profile.name
  monitoring              = false
  vpc_security_group_ids  = [var.ghost_security_group]
  subnet_id               = var.ghost_subnet_id

  key_name                = var.ghost_key_pair

  tags                    = var.tags
}