# Copyright 2023-2024 Broadcom. All rights reserved.
# SPDX-License-Identifier: BSD-2

/*
    DESCRIPTION:
    Ubuntu Server 22.04 LTS build definition.
    Packer Plugin for VMware vSphere: 'vsphere-iso' builder.
*/

//  BLOCK: packer
//  The Packer configuration.

packer {
  required_version = ">= 1.10.0"
  required_plugins {
    vsphere = {
      source  = "github.com/hashicorp/vsphere"
      version = ">= 1.2.4"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.6.1"
    }
  }
}

//  BLOCK: data
//  Defines the data sources.

data "git-repository" "cwd" {}

//  BLOCK: locals
//  Defines the local variables.

locals {
  build_by   = "Built by: HashiCorp Packer ${packer.version}"
  build_date = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  // build_version     = data.git-repository.cwd.head
  build_version      = "k3snode"
  build_description  = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  iso_paths          = ["[${var.common_iso_datastore}] ${var.iso_path}/${var.iso_file}"]
  manifest_date      = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path      = "${path.cwd}/manifests/"
  manifest_output    = "${local.manifest_path}${local.manifest_date}.json"
  ovf_export_path    = "${path.cwd}/artifacts/${local.vm_name}"
  vm_name            = "${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}-${local.build_version}"
  bucket_name        = replace("${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}", ".", "")
  bucket_description = "${var.vm_guest_os_family} ${var.vm_guest_os_name} ${var.vm_guest_os_version}"
  // shell_scripts       = ["${abspath(path.root)}/scripts/setup.sh"]
}


//  BLOCK: source
//  Defines the builder configuration blocks.

source "vsphere-clone" "linux-ubuntu-k3snode" {
  // vCenter Server Endpoint Settings and Credentials
  vcenter_server      = var.vsphere_endpoint
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure_connection

  // vSphere Settings
  datacenter                     = var.vsphere_datacenter
  cluster                        = var.vsphere_cluster
  host                           = var.vsphere_host
  datastore                      = var.vsphere_datastore
  folder                         = var.vsphere_folder
  resource_pool                  = var.vsphere_resource_pool
  set_host_for_datastore_uploads = var.vsphere_set_host_for_datastore_uploads

  // Virtual Machine Settings
  vm_name         = local.vm_name
  firmware        = var.vm_firmware
  CPUs            = var.vm_cpu_count
  cpu_cores       = var.vm_cpu_cores
  CPU_hot_plug    = var.vm_cpu_hot_add
  RAM             = var.vm_mem_size
  RAM_hot_plug    = var.vm_mem_hot_add
  cdrom_type      = var.vm_cdrom_type
  remove_cdrom    = var.common_remove_cdrom
  reattach_cdroms = var.vm_cdrom_count


  // Clone Configuration
  template             = var.from_template
  disk_size            = var.vm_disk_size
  network              = var.vsphere_network
  disk_controller_type = var.vm_disk_controller_type
  notes                = local.build_description
  tools_upgrade_policy = var.common_tools_upgrade_policy
  customize {
    linux_options {
      host_name = "localhost"
      domain    = "test.internal"
      time_zone = var.vm_guest_os_timezone
    }
    network_interface {
      ipv4_address = var.vm_ip_address
      ipv4_netmask = var.vm_ip_netmask
    }
    ipv4_gateway    = var.vm_ip_gateway
    dns_server_list = var.vm_dns_list
  }

  // Boot and Provisioning Settings
  ip_wait_timeout   = var.common_ip_wait_timeout
  ip_settle_timeout = var.common_ip_settle_timeout
  shutdown_command  = "echo '${var.build_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout  = var.common_shutdown_timeout


  // Communicator Settings and Credentials
  communicator       = "ssh"
  ssh_proxy_host     = var.communicator_proxy_host
  ssh_proxy_port     = var.communicator_proxy_port
  ssh_proxy_username = var.communicator_proxy_username
  ssh_proxy_password = var.communicator_proxy_password
  ssh_host           = var.vm_ip_address
  ssh_username       = var.build_username
  ssh_password       = var.build_password
  ssh_port           = var.communicator_port
  ssh_timeout        = var.communicator_timeout

  // Template and Content Library Settings
  convert_to_template = var.common_template_conversion
  dynamic "content_library_destination" {
    for_each = var.common_content_library_name != null ? [1] : []
    content {
      library     = var.common_content_library_name
      description = local.build_description
      ovf         = var.common_content_library_ovf
      destroy     = var.common_content_library_destroy
      skip_import = var.common_content_library_skip_export
    }
  }

  // OVF Export Settings
  dynamic "export" {
    for_each = var.common_ovf_export_enabled == true ? [1] : []
    content {
      name  = local.vm_name
      force = var.common_ovf_export_overwrite
      options = [
        "extraconfig"
      ]
      output_directory = local.ovf_export_path
    }
  }
}


//  BLOCK: build
//  Defines the builders to run, provisioners, and post-processors.

build {
  sources = ["vsphere-clone.linux-ubuntu-k3snode"]

  provisioner "shell" {
    execute_command = "echo '${var.build_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    inline = [
      "truncate -s 0 /etc/machine-id",
      "rm /var/lib/dbus/machine-id",
      "ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sed -i -e \"s/GRUB_CMDLINE_LINUX_DEFAULT=\\\"\\(.*\\)\\\"/GRUB_CMDLINE_LINUX_DEFAULT=\\\"\\\"/\" /etc/default/grub",
      "apt update && apt install -y nfs-common python3-pip",
    ]
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      ansible_username         = var.ansible_username
      build_username           = var.build_username
      build_date               = local.build_date
      build_version            = local.build_version
      common_data_source       = var.common_data_source
      common_vm_version        = var.common_vm_version
      vm_cpu_cores             = var.vm_cpu_cores
      vm_cpu_count             = var.vm_cpu_count
      vm_disk_size             = var.vm_disk_size
      vm_disk_thin_provisioned = var.vm_disk_thin_provisioned
      vm_firmware              = var.vm_firmware
      vm_guest_os_type         = var.vm_guest_os_type
      vm_mem_size              = var.vm_mem_size
      vm_network_card          = var.vm_network_card
      vsphere_cluster          = var.vsphere_cluster
      vsphere_host             = var.vsphere_host
      vsphere_datacenter       = var.vsphere_datacenter
      vsphere_datastore        = var.vsphere_datastore
      vsphere_endpoint         = var.vsphere_endpoint
      vsphere_folder           = var.vsphere_folder
    }
  }

  dynamic "hcp_packer_registry" {
    for_each = var.common_hcp_packer_registry_enabled ? [1] : []
    content {
      bucket_name = local.bucket_name
      description = local.bucket_description
      bucket_labels = {
        "os_family" : var.vm_guest_os_family,
        "os_name" : var.vm_guest_os_name,
        "os_version" : var.vm_guest_os_version,
      }
      build_labels = {
        "build_version" : local.build_version,
        "packer_version" : packer.version,
      }
    }
  }
}
