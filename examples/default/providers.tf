provider "aws" {
  #region  = local.aws_region
  region  = var.aws_region
  version = "3.20"
}
