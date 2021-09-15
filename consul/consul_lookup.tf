resource "consul_keys" "nslookup" {
  # key is the vm name, value is the ip address
  key {
    path   = "nslookup/${var.vm_name}"
    value  = local.instance_public_ip
    delete = true
  }
}

