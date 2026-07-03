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

module "jungle_cleaner" {
  # Direct GitHub source — works today. Once this module is published to the
  # Terraform Registry, "JungleCleaner/jungle-cleaner/aws" works too (same code).
  source = "github.com/JungleCleaner/terraform-aws-jungle-cleaner"

  # Get this token from https://junglecleaner.com — either the "connect_aws"
  # MCP tool response, or the "Connect AWS account" button on your dashboard.
  external_id = "conn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

output "role_arn" {
  value = module.jungle_cleaner.role_arn
}
