provider "aws" {
  region  = var.aws_region
}

terraform {
  backend "s3" {
    bucket = "tamu-engr-shared-services-terraform-deploy"
    key    = "terraform-aws-github-runner/engr-account-lifecycle-runner"
    region = "us-east-2"
    dynamodb_table = "aws-tf-locks"
  }
}
