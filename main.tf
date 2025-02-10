# Créer un VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "monVpc"
  }
}

# Créer un sous-réseau public
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "var.subnet_a_ip"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

# Créer deux sous-réseaux privés
resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "var.subnet_b_ip"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "subnet_b"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-2"
  }
}

# Créer une table de routage pour le VPC
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "main-route-table"
  }
}

# Ajouter une route vers Internet pour le sous-réseau public
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "main-internet-gateway"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.main_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# Associer la table de routage au sous-réseau public
resource "aws_route_table_association" "subnet_a_association" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.main_route_table.id
}

# Créer une table de routage privée (par exemple, pour un NAT Gateway)
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "private-route-table"
  }
}

# Associer les sous-réseaux privés à la table de routage privée
resource "aws_route_table_association" "subnet_b_association" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Créer un Security Group pour les connexions SSH
resource "aws_security_group" "ssh_access_sg" {
  name        = "ssh-access-sg"
  description = "Allow SSH access from VPC"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Autoriser tout le VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh-access-sg"
  }
}

# Créer un Security Group général
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "ec2-security-group"
  }
}

# Créer un Load Balancer avec deux sous-réseaux
resource "aws_lb" "main_lb" {
  name               = "my-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_security_group.id]  # Correction : nom du SG mis à jour
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id] # Ajout du 2ème sous-réseau
  enable_deletion_protection = false

  tags = {
    Name = "my-app-lb"
  }
}

# Récupérer la clé SSH pour l'authentification
data "aws_key_pair" "vockey" {
  key_name = "vockey"
}

# Créer une instance EC2 publique POUR SITE WEB
resource "aws_instance" "ec2_instance_public" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = data.aws_key_pair.vockey.key_name 
  subnet_id     = aws_subnet.subnet_a.id

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              echo "I am the new Elden Lord !" > /var/www/html/index.html
              systemctl start httpd
              systemctl enable httpd
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "my-ec2-instance-public"
  }
}

# Créer une instance EC2 privée
resource "aws_instance" "ec2_instance_private" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2 AMI
  instance_type = "t2.micro"
  key_name      = data.aws_key_pair.vockey.key_name 
  subnet_id     = aws_subnet.subnet_b.id

  associate_public_ip_address = false

  vpc_security_group_ids = [aws_security_group.ssh_access_sg.id]

  tags = {
    Name = "my-ec2-instance-private"
  }
}

# Créer une Elastic IP
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

# Créer une NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet_a.id

  tags = {
    Name = "nat-gateway"
  }
}

# Ajouter une route NAT Gateway pour les sous-réseaux privés
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

# Créer un Target Group
resource "aws_lb_target_group" "main_target_group" {
  name     = "my-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-299"
  }

  tags = {
    Name = "my-app-target-group"
  }
}

# Créer un Listener pour le Load Balancer
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_target_group.arn
  }
}

# Attacher les instances au Target Group
resource "aws_lb_target_group_attachment" "ec2_instance_public_attachment" {
  target_group_arn = aws_lb_target_group.main_target_group.arn
  target_id        = aws_instance.ec2_instance_public.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "ec2_instance_private_attachment" {
  target_group_arn = aws_lb_target_group.main_target_group.arn
  target_id        = aws_instance.ec2_instance_private.id
  port             = 80
}
