terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket = "apexforlife-tfstate"
    key    = "nico-pico.com.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region  = "us-east-1"
}

module "github_publish_to_s3" {
  source = "./github-publish-to-s3"

  domain = "nico-pico.com"
}