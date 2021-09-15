resource "aws_key_pair" "local_key_pair" {
  key_name   = "local_ssh_key_pair_${var.vm_name}"
  public_key = data.local_file.public_key.content
#  private_key = data.local_file.private_key.content
}

