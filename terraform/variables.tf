variable "region" {
  description = "OCI home region for Always Free resources."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "Set the OCI region identifier, not the display name."
  }
}

variable "oci_config_profile" {
  description = "API-key profile in ~/.oci/config. Private credentials stay outside Terraform."
  type        = string
  default     = "DEFAULT"
  nullable    = false
}

variable "compartment_ocid" {
  description = "Existing OCI compartment; Terraform does not manage IAM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ocid1\\.compartment\\.", var.compartment_ocid))
    error_message = "Provide the existing compartment OCID."
  }
}

variable "availability_domain" {
  description = "OCI availability domain for the K3s VM; choose another AD if A1 capacity is unavailable."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.availability_domain)) > 0
    error_message = "Provide an availability domain in the chosen region."
  }
}

variable "image_ocid" {
  description = "Pinned Ubuntu 24.04 aarch64 image OCID in the chosen region."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^ocid1\\.image\\.", var.image_ocid))
    error_message = "Provide an OCI image OCID for Ubuntu ARM64."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the operator's PUBLIC SSH key (.pub), never the private key."
  type        = string
  nullable    = false

  validation {
    condition     = endswith(var.ssh_public_key_path, ".pub")
    error_message = "Point to a .pub file, not a private key."
  }
}

variable "ssh_source_cidr" {
  description = "Current public IPv4 address of the SSH operator as a single-host /32."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.ssh_source_cidr)) &&
      can(cidrhost(var.ssh_source_cidr, 0)) &&
      var.ssh_source_cidr != "0.0.0.0/32"
    )
    error_message = "Use a valid, nonzero, public operator IPv4 address ending in /32."
  }
}
