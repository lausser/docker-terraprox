resource "aws_instance" "instance" {
  ami                         = var.instance_ami
  availability_zone           = "${var.aws_region}${var.aws_region_az}"
  instance_type               = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = [data.aws_security_group.sg.id]
  subnet_id                   = data.aws_subnet.subnet.id
  key_name                    = "local_ssh_key_pair_${var.vm_name}"
 
  root_block_device {
    delete_on_termination = true
    encrypted             = false
    volume_size           = var.root_device_size
    volume_type           = var.root_device_type
  }
 
  tags = {
    "Owner"               = var.owner
    "Name"                = "${var.owner}-${var.vm_name}-instance"
    "KeepInstanceRunning" = "false"
  }

  connection {
    type     = "ssh"
    host     = coalesce(self.public_ip, self.private_ip)
    private_key = data.local_file.private_key.content
    user     = var.ssh_user
    password = var.ssh_password
    #password = rsadecrypt(self.password_data, file("<path to the private key>"))
  }

}

