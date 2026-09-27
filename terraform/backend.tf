terraform {
  backend "s3" {
    bucket       = "cloud-design-tfstate-063298175314"
    key          = "cloud-design/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
