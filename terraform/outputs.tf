output "instance_id" {
  description = "OCI instance OCID."
  value       = oci_core_instance.lab.id
}

output "public_ip" {
  description = "SSH endpoint; OCI security list allows the operator's /32 only."
  value       = oci_core_instance.lab.public_ip
}

output "ssh_command" {
  description = "SSH command using the private key that matches ssh_public_key_path."
  value       = "ssh -i \"${trimsuffix(var.ssh_public_key_path, ".pub")}\" ubuntu@${oci_core_instance.lab.public_ip}"
}
