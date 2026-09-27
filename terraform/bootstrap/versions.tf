terraform {
  required_version = ">= 1.16.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Deliberately local state: this config creates the bucket the *other*
  # root configs will use for remote state, so it can't depend on that
  # bucket existing yet. One-time, low-risk, run by whoever sets this up.
}
