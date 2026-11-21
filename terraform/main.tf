locals {
  name = "k3s-lab"
}

resource "oci_core_vcn" "lab" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.30.0.0/16"]
  display_name   = "${local.name}-vcn"
  dns_label      = "k3slab"
}

resource "oci_core_internet_gateway" "lab" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab.id
  display_name   = "${local.name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "lab" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab.id
  display_name   = "${local.name}-routes"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.lab.id
  }
}

# Do not attach the VCN's default security list: OCI's default can permit SSH
# from anywhere. This list admits only the operator's /32; K3s API and apps
# have no public ingress. Outbound access is needed for OS/K3s updates.
resource "oci_core_security_list" "lab" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.lab.id
  display_name   = "${local.name}-security"

  ingress_security_rules {
    description = "SSH from operator only"
    protocol    = "6"
    source      = var.ssh_source_cidr

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    description = "ICMP fragmentation-needed for path MTU discovery"
    protocol    = "1"
    source      = "0.0.0.0/0"

    icmp_options {
      type = 3
      code = 4
    }
  }

  egress_security_rules {
    description = "Outbound package and K3s downloads"
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "lab" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.lab.id
  cidr_block                 = "10.30.1.0/24"
  display_name               = "${local.name}-subnet"
  dns_label                  = "node"
  route_table_id             = oci_core_route_table.lab.id
  security_list_ids          = [oci_core_security_list.lab.id]
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_instance" "lab" {
  compartment_id       = var.compartment_ocid
  availability_domain  = var.availability_domain
  display_name         = local.name
  shape                = "VM.Standard.A1.Flex"
  preserve_boot_volume = false

  shape_config {
    ocpus         = 1
    memory_in_gbs = 8
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_ocid
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.lab.id
    assign_public_ip = true
    hostname_label   = "k3s"
  }

  metadata = {
    ssh_authorized_keys = trimspace(file(pathexpand(var.ssh_public_key_path)))
  }

  lifecycle {
    # VM replacement/deletion requires consciously removing this guard first.
    prevent_destroy = true
  }
}
