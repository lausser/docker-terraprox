variable "owner" {
  description = "Configuration owner"
  type        = string
}

variable "image" {
  description = "name of the image/snapshot to use"
  type        = string
  default     = "t-debian-9.13"
}
 
variable "instance_type" {
  description = "Type of the instance"
  type        = string
  default     = "cx21"
}

variable "instance_location" {
  description = "Location of the instance"
  type        = string
  default     = "nbg1"
}

variable "private_network" {
  description = "An optional private network"
  type = set(object(
    {
      alias_ips   = set(string)
      ip          = string
      mac_address = string
      network_id  = number
    }
  ))
  default = []
}

variable "ssh_user" {
  description = "Name of the ssh user"
  type        = string
  default     = "admin"
}

variable "ssh_password" {
    type = string
    default = "geheim"
}

variable "otf_ssh_password_encrypted" {
    type = string
    default = "$2$geheim"
}

variable "vm_name" {
    type = string
    default = "myvm"
}

variable "ansible_playbook" {
    type = string
    default = "packer.yml"
}

