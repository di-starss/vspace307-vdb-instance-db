/**

    $ VDB-INSTANCE-DB, v.3.0 2021/10/14 05:34 Exp @di $

    role: [ master,slave,delay ], need for set tag's (generate dynamics inventory)

**/

terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.35.0"
    }
  }
}


//
// VARIABLES
//

variable "instance_name" {}

variable "env" {}
variable "project" {}
variable "service" {}

variable "role" {}

variable "consul_host" {}
variable "consul_port" {}
variable "consul_schema" {}

variable "site" {}
variable "image" {}
variable "flavor" {}
variable "key" {}
variable "security_group" {}
variable "server_group" {}

variable "ansible_playbook" {}

variable "volume" {}
variable "disk_boot_size" {}
variable "disk_data_size" {}

variable "mgmt_user" {}
variable "mgmt_private_key" {}

variable "net" {}
variable "ip" {}

variable "vdb_id" {}
variable "vdb_delay" { default = 0 }


// Instance
resource "openstack_compute_instance_v2" "instance" {

  name              = var.instance_name
  flavor_id         = var.flavor
  key_pair          = var.key
  security_groups   = ["default", var.security_group]
  availability_zone = var.site

  scheduler_hints {
    group = var.server_group
  }

  tags = [
    "${var.project}_${var.env}_${var.service}",
    "${var.project}_${var.env}_${var.service}_${var.site}",
    "${var.project}_${var.env}_${var.service}_${var.role}"
  ]

  block_device {
    uuid                  = var.image
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.disk_boot_size
    volume_type           = var.volume
    delete_on_termination = true
  }

  block_device {
    source_type           = "blank"
    destination_type      = "volume"
    volume_size           = var.disk_data_size
    volume_type           = var.volume
    boot_index            = 1
    delete_on_termination = true
  }

  network {
    name = var.net
    fixed_ip_v4 = var.ip
  }

  metadata = {
    env = var.env
    project = var.project
    service = var.service

    consul_host = var.consul_host
    consul_port = var.consul_port
    consul_schema = var.consul_schema

    vdb_id = var.vdb_id
    vdb_delay = var.vdb_delay
  }

  // ansible/upload
  provisioner "file" {
    source      = "${path.module}/ansible"
    destination = "/tmp/ansible"

    connection {
      type     = "ssh"
      user     = var.mgmt_user
      private_key = file(var.mgmt_private_key)
      host = var.ip
    }
  }

  // ansible/run
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install gnupg2 -y",
      "echo 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu focal main' | sudo tee -a /etc/apt/sources.list",
      "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367",
      "sudo apt update",
      "sudo apt install ansible -y",
      "sudo ansible-playbook /tmp/ansible/${var.ansible_playbook}"
    ]

    connection {
      type     = "ssh"
      user     = var.mgmt_user
      private_key = file(var.mgmt_private_key)
      host = var.ip
    }
  }

}

