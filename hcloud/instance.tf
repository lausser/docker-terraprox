data "hcloud_image" "thisimage" {
  with_selector = "image=${var.image}"
}

resource "hcloud_server" "instance" {
  name = var.vm_name
  image = data.hcloud_image.thisimage.id
  server_type = var.instance_type
  location = var.instance_location
  network = var.private_network
  #datacenter = "${var.datacenter}"
  #ssh_keys = [ "${hcloud_ssh_key.local.id}" ]

  connection {
    type     = "ssh"
    host = hcloud_server.instance.ipv4_address
    user     = var.ssh_user
    password     = var.ssh_password
    #private_key = "${file("~/.ssh/id_rsa")}"
  }

  provisioner "remote-exec" {
    inline = [
      "echo connected"
    ]
  }

}
