provider "oci" {
  auth                = "APIKey"
  region              = var.region
  config_file_profile = var.oci_config_profile
}
