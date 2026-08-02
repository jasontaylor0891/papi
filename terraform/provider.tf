terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# CloudFront only reads ACM certificates from us-east-1, regardless of which
# region the rest of the infrastructure lives in.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
