data "aws_security_group" "sg" {
  filter {
    name = "tag:Owner"
    values = ["${var.owner}"]
  }
  filter {
    name = "tag:Name"
    values = ["${var.owner}-sg"]
  }
}
