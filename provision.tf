resource "null_resource" "provisioning" {
  triggers = {
    public_ip = local.instance_public_ip
  }

  provisioner "local-exec" {
    command =<<EOCMD
    printf "[defaults]\nhost_key_checking = False\n" > ~/.ansible.cfg
    ansible -m ping -i ${local.instance_public_ip}, -u ${var.ssh_user} --extra-vars ansible_ssh_pass=${var.ssh_password} all
    EOCMD
  }

  provisioner "local-exec" {
    command =<<EOCMD
    ansible -m shell -i ${local.instance_public_ip}, -u ${var.ssh_user} --extra-vars ansible_ssh_pass=${var.ssh_password} all -a "export PATH=/usr/bin:/bin:/usr/sbin:/sbin; ip a"
    EOCMD
  }

  provisioner "local-exec" {
    command =<<EOCMD
    if [ "${var.ssh_user}" != "packer" ]; then
      ansible-playbook ansible/playbooks/packer.yml -i ${local.instance_public_ip}, -u ${var.ssh_user} -b
    fi
    EOCMD
  }

  provisioner "local-exec" {
    command =<<EOCMD
    ansible-playbook ansible/playbooks/otf_password.yml -i ${local.instance_public_ip}, -u ${var.ssh_user} -b --extra-vars 'otf_ssh_password=${var.otf_ssh_password_encrypted}'
    EOCMD
  }

  provisioner "local-exec" {
    command =<<EOCMD
    ansible-playbook ansible/playbooks/route.yml -i ${local.instance_public_ip}, -u ${var.ssh_user} -b
    EOCMD
  }

}

