provider "proxmox" {
  pm_tls_insecure = true
  pm_log_enable = true
  pm_log_file = "terraform-plugin-proxmox.log"
  pm_log_levels = {
    _default = "debug"
    _capturelog = ""
  }
  pm_parallel = 1
  pm_timeout = 600
}

resource "proxmox_vm_qemu" "instance" {
  name = var.vm_name
  desc = var.vm_desc
  target_node = var.target_node
  clone = var.vm_clone
  full_clone = false
  boot = "c"
  agent = 1

  os_type = "cloud-init"
  ipconfig0 = "ip=dhcp"

  # The destination resource pool for the new VM
  pool = var.target_pool

  cores = var.cpu_cores
  sockets = var.cpu_sockets
  memory = var.memory

  vga {
    type = "std"
    memory = 4
  }

  network {
    bridge = "vmbr0"
    model = "virtio"
  }

  disk {
    type = "virtio"
    storage = var.disk_storage
    size = var.disk_size
    backup = 0
    iothread = 1
    #cache = var.disk_cache
  }

  connection {
    user = var.ssh_user
    password = var.ssh_password
    host = self.ssh_host
    # has preference over the password
#    private_key = data.local_file.private_key.content
  }

  provisioner "local-exec" {
    command =<<EOCMD
    if [ -f terraform-plugin-proxmox.log ]; then
      cat terraform-plugin-proxmox.log
    fi
    EOCMD
  }

  provisioner "remote-exec" {
    inline = [
      "echo connected"
    ]
  }

}
