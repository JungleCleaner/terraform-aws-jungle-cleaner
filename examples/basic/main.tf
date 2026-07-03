terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Get this token from https://junglecleaner.com — either the "connect_aws"
# MCP tool response, or the "Connect AWS account" button on your dashboard.
# Passed via -var="external_id=..." so `terraform apply` works right after
# cloning, no file editing required.
variable "external_id" {
  type = string
}

module "jungle_cleaner" {
  # Relative path because this example lives inside the module's own repo —
  # this is also what makes `terraform apply` runnable directly from here
  # right after cloning, no other file edits needed. If you're copying this
  # snippet into your OWN project instead, replace this with:
  #   source = "github.com/JungleCleaner/terraform-aws-jungle-cleaner"
  # (or, once published, the shorter "JungleCleaner/jungle-cleaner/aws" form).
  source = "../../"

  external_id = var.external_id
}

output "role_arn" {
  value = module.jungle_cleaner.role_arn
}
