locals {
  environment = "test"
  #aws_region  = "us-east-2"
  vpc_id = "vpc-01bc2d2d3ed5f3180"
  private_subnets = ["subnet-06cea91a196c830e9"]
}

resource "random_password" "random" {
  length = 28
}

module "runners" {
  source = "../../"

  #aws_region = local.aws_region
  aws_region = var.aws_region
  #vpc_id     = module.vpc.vpc_id
  vpc_id     = local.vpc_id
  #subnet_ids = module.vpc.private_subnets
  subnet_ids = local.private_subnets

  environment = local.environment
  tags = {
    Project = "terraform-aws-github-runner-test"
  }

  github_app = {
    key_base64     = var.github_app_key_base64
    id             = var.github_app_id
    client_id      = var.github_app_client_id
    client_secret  = var.github_app_client_secret
    webhook_secret = random_password.random.result
  }

  webhook_lambda_zip                = "lambdas-download/webhook.zip"
  runner_binaries_syncer_lambda_zip = "lambdas-download/runner-binaries-syncer.zip"
  runners_lambda_zip                = "lambdas-download/runners.zip"
  enable_organization_runners       = false
  runner_extra_labels               = "default,example"

  # enable access to the runners via SSM
  enable_ssm_on_runners = true

  # Uncommet idle config to have idle runners from 9 to 5 in time zone Amsterdam
  # idle_config = [{
  #   cron      = "* * 9-17 * * *"
  #   timeZone  = "Europe/Amsterdam"
  #   idleCount = 1
  # }]

  # disable KMS and encryption
  # encrypt_secrets = false

  # Let the module manage the service linked role
  # create_service_linked_role_spot = true
}
