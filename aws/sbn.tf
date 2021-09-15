data "aws_subnet" "subnet" {
  filter {
    name = "tag:Owner"
    values = ["${var.owner}"]
  }
  filter {
    name = "tag:Name"
    values = ["${var.owner}-subnet"]
  }
}
