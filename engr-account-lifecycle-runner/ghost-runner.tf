locals {
  ghost_tags = merge(var.tags, {
    Environment = "ghost-${var.environment}"
    Name = "ghost-${var.environment}"
  })
}

module "ghost-runner" {
  source = "../modules/ghost-runner"

  aws_region            = var.aws_region
  tags                  = local.ghost_tags
  vpc_id                = var.vpc_id
  ghost_subnet_id       = var.subnet_ids[0]
  ghost_security_group  = "sg-04bbde937ed7612b9"
  ghost_ec2_role        = var.ghost_ec2_role
  environment           = var.environment
  ghost_key_pair        = var.ghost_key_pair
}

module "start-ghost-runner-weekly" {
  source                         = "diodonfrost/lambda-scheduler-stop-start/aws"
  name                           = "ghost-${var.environment}-starter"
  # 4:00am Central on Sun
  cloudwatch_schedule_expression = "cron(00 10 ? * SUN *)"
  schedule_action                = "start"
  ec2_schedule                   = "true"
  rds_schedule                   = "false"
  autoscaling_schedule           = "false"
  resources_tag                  = {
    key   = "Name"
    value = "ghost-${var.environment}"
  }
}