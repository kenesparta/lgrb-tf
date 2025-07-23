resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "lgrb-igw"
    Project = var.project
    Owner   = var.owner
  }
}
