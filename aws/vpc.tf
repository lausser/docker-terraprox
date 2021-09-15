data "aws_vpc" "vpc" {
  filter {
    name = "tag:Owner"
    values = ["${var.owner}"]
  }
  filter {
    name = "tag:Name"
    values = ["${var.owner}-vpc"]
  }
}
