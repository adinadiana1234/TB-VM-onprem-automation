provider "oci" {}

data "oci_core_images" "compute_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E4.Flex"
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  filter {
    name   = "launch_mode"
    values = ["NATIVE"]
  }
}

data "cloudinit_config" "config" {
  gzip          = false
  base64_encode = true
  part {
    filename     = "cloudinit.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/cloudinit.sh",
	  { postgres_password = var.postgres_password
      })
  }
}

resource "oci_core_instance" "this" {
	availability_domain = var.ad
	compartment_id = var.compartment_ocid
	display_name = var.vm_display_name

	create_vnic_details {
		assign_ipv6ip = "false"
		assign_private_dns_record = "true"
		assign_public_ip = "true"
		subnet_id = var.subnet_id
	}
	
	shape_config {
		ocpus = 1  # Specify the number of OCPUs for the flexible instance shape
	}

	metadata = {
		ssh_authorized_keys = var.ssh_public_key
		user_data           = data.cloudinit_config.config.rendered
	}
	shape = "VM.Standard.E4.Flex"
	source_details {
	 	source_id = data.oci_core_images.compute_images.images[0].id
		source_type = "image"
	}
	freeform_tags = {"COMPUTE_TAG"= "TB_instance"}

}
