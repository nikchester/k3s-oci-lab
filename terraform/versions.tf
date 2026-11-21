terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "= 9.11.0"
    }
  }

  # Local state for the initial single-operator setup. Never commit state.
  backend "local" {}
}
