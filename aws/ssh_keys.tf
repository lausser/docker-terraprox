data "local_file" "private_key" {
  filename = "${path.module}/.ssh/id_rsa"
}

data "local_file" "public_key" {
  filename = "${path.module}/.ssh/id_rsa.pub"
}

