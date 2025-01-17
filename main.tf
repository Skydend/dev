resource "aws_vpc" "vpc" {
    cidr_block = var.awn_vpc

    tags = {
        Name = "monVpc"
    }
}

resource "aws_subnet" "subnet_a" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.subnet_a_ip
}

resource "aws_subnet" "subnet_b" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.subnet_b_ip
}

resource "aws_eip" "nat" {
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet_a.id

  tags = {
    Name = "NAT-Gateway"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private-Route-Table"
  }
}

resource "aws_route_table_association" "private_subnet_a" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.private.id
}


resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion-SG"
  }
}