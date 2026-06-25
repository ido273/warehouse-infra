terraform {
  backend "s3" {
    bucket = "warehouse-terraform-state-ido273"
    key    = "terraform.tfstate"
    region = "eu-west-1"
  }
}