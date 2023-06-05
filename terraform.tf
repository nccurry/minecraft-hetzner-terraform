terraform {
  required_version = ">= 0.14"
    required_providers {
      hcloud = {
        source = "hetznercloud/hcloud"
        version = ">= 1.39.0, < 2.0.0"
      }
    }
}

variable "app_name" {
  description = "The name of this application"
  type        = string
  default     = "minecraft"
}

variable "deployment_name" {
  description = "The unique name of this deployment"
  type        = string
  default     = "main"
}

variable "server_image" {
  description = "Image for the server."
  type        = string
  default     = "fedora-38"

}

variable "server_type" {
  description = "The type of server to deploy."
  type        = string
  default     = "cpx31"
}

variable "server_location" {
  description = "The location to deploy the server."
  type        = string
  default     = "ash"
}

variable "allowlisted_cidr_ranges" {
  description = "The CIDR ranges that can communicate with the infrastructure"
  type        = list(string)
}

variable "private_ssh_key_dir" {
  description = "Path to download local private SSH key"
  type        = string
  default     = "~/.ssh"
}

variable "download_private_ssh_key" {
  description = "Whether to download the ssh private key locally"
  type        = bool
  default     = true
}

variable "data_volume_size" {
  description = "The size of the data volume in GB"
  type = number
  default = 50
}

variable "data_volume_device" {
  description = "The device name of the data volume"
  type = string
  default = "/dev/sdb"
}

variable "data_volume_mount_path" {
  description = "The mount path of the data volume"
  type = string
  default = "/opt/mcserver"
}

variable "data_volume_snapshot_schedule" {
  description = "How often to snapshot the data volume"
  type = string
  default = "0 0 * * *"
}

# https://github.com/mtoensing/Docker-Minecraft-PaperMC-Server
variable "papermc_container_image" {
  description = "The container image to use for the papermc container"
  type        = string
  default     = "docker.io/marctv/minecraft-papermc-server"
}

# https://hub.docker.com/r/marctv/minecraft-papermc-server/tags
variable "papermc_container_tag" {
  description = "The container tag to use for the papermc container"
  type        = string
  default     = "1.19"
}

variable "papermc_server_memory_size" {
  description = "The value for the papermc container MEMORYSIZE environment variable"
  type        = string
  default = "6G"
}

resource "tls_private_key" "default" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "default" {
  name       = "${var.app_name}-${var.deployment_name}"
  public_key = tls_private_key.default.public_key_openssh
}

resource "hcloud_firewall" "default" {
  name = "${var.app_name}-${var.deployment_name}"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = var.allowlisted_cidr_ranges
  }

  # Java edition
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "25565"
    source_ips = var.allowlisted_cidr_ranges
  }

  # Bedrock edition
  rule {
    direction = "in"
    protocol  = "udp"
    port      = "19132"
    source_ips = var.allowlisted_cidr_ranges
  }

  # Plan
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "8804"
    source_ips = var.allowlisted_cidr_ranges
  }

  # Bluemap
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "8100"
    source_ips = var.allowlisted_cidr_ranges
  }
}

resource "hcloud_server" "default" {
  name        = "${var.app_name}-${var.deployment_name}"
  image       = var.server_image
  server_type = var.server_type
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.default.id]
  firewall_ids = [hcloud_firewall.default.id]
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
  labels = {
    "app" : var.app_name
    "deployment": var.deployment_name
  }
  user_data = templatefile("${path.module}/files/user-data.yaml.tpl", {
    public_ssh_key = tls_private_key.default.public_key_openssh,
    partition_and_mount_disk_sh_contents =  templatefile("${path.module}/files/partition-and-mount-disk.sh.tpl", {
      data_volume_device = var.data_volume_device
      data_volume_mount_path = var.data_volume_mount_path
    })
    download_papermc_plugins_sh_contents = templatefile("${path.module}/files/download-papermc-plugins.sh.tpl", {
      data_volume_mount_path = var.data_volume_mount_path
    })
    mcserver_service_contents = templatefile("${path.module}/files/mcserver.service.tpl", {
      data_volume_mount_path = var.data_volume_mount_path
      papermc_container_image = var.papermc_container_image
      papermc_container_tag = var.papermc_container_tag
      papermc_server_memorysize = var.papermc_server_memory_size
    })
  })
}

resource "hcloud_volume" "default" {
  name = "${var.app_name}-${var.deployment_name}-data"
  size = var.data_volume_size
  location = var.server_location
  format = "xfs"
}

resource "hcloud_volume_snapshot" "my_volume_snapshot" {
  volume_id  = hcloud_volume.default.id
  name       = "${var.app_name}-${var.deployment_name}-data"
  schedule   = var.data_disk_snapshot_schedule
}

resource "hcloud_volume_attachment" "default" {
  server_id = hcloud_server.default.id
  volume_id = hcloud_volume.default.id
}

resource "local_sensitive_file" "default" {
  count           = var.download_private_ssh_key ? 1 : 0
  content         = tls_private_key.default.private_key_pem
  filename        = pathexpand("${var.private_ssh_key_dir}/${var.app_name}-${var.deployment_name}.pem")
  file_permission = "0600"
}

output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no -i ${pathexpand("${var.private_ssh_key_dir}/${var.app_name}-${var.deployment_name}.pem")} fedora@${hcloud_server.default.ipv4_address}"
}