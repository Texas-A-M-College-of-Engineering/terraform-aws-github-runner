variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "vpc_id" {
  description = "The VPC for the security groups."
  type        = string
}

variable "ghost_subnet_id" {
  description = "Subnet in which the ghost runner will be launched, the subnet needs to be a subnet in the `vpc_id`."
  type        = string
}

variable "tags" {
  description = "Map of tags that will be added to created resources. By default resources will be tagged with name and environment."
  type        = map(string)
  default     = {}
}

variable "ghost_instance_type" {
  description = "Default instance type for the action runner."
  type        = string
  default     = "t2.micro"
}

variable "ghost_ami_filter" {
  description = "String used to create the AMI filter for the ghost action runner AMI."
  type        = string

  default = "amzn2-ami-hvm-2.*-x86_64-ebs"
}

variable "ghost_security_group" {
  description = "The name of the security group to use for launching the instance"
  type        = string
}

variable "ghost_ec2_role" {
  description = "Name of the EC2 role that will be used to launch the ghost runner"
  type        = string
}

variable "environment" {
  description = "A name that identifies the environment, used as prefix and for tagging."
  type        = string
}

variable "ghost_key_pair" {
  description = "Key pair name for connecting via SSH (optional)"
  type        = string
  default     = null
}
