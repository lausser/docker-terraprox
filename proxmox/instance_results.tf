locals {
  instance_id = proxmox_vm_qemu.instance.ssh_host
  instance_public_ip = proxmox_vm_qemu.instance.ssh_host
}
