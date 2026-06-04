terraform {
  backend "s3" {
    bucket  = "project-bedrock-tfstate-3765"
    key     = "state/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
