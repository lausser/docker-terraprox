locals {
  instance_id = hcloud_server.instance.id
  instance_public_ip = hcloud_server.instance.ipv4_address
}

