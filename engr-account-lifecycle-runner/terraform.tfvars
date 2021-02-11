aws_region = "us-east-2"
vpc_id = "vpc-0633fa488037fafb0"
subnet_ids = ["subnet-09411b3c180747e73"]

tags = {
  #environment = "dev"
  unit = "EIT"
  owner = "EIT"
  group = "cloud"
  portfolio = "automation"
  service = "identity"
}

instance_type = "m5.large"

environment = "engr-lc-github-runner"

enable_organization_runners = false

minimum_running_time_in_minutes = "60"

webhook_lambda_zip = "../examples/default/lambdas-download/webhook.zip"
runners_lambda_zip = "../examples/default/lambdas-download/runners.zip"
runner_binaries_syncer_lambda_zip = "../examples/default/lambdas-download/runner-binaries-syncer.zip"

runners_maximum_count = 1

runner_extra_labels = "aws-runner-engr-lc-shared-services"

enable_ssm_on_runners = true
