resource "aws_vpc" "tpfinal" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "VPC-FINAL"
  }
}

// SOUS-RESEAUX

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Plages d'adresses des sous-réseaux publics"
  default     = ["10.0.0.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Plages d'adresses des sous-réseaux privés"
  default     = ["10.0.1.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a"]
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.tpfinal.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)


  tags = {
    Name = "tpfinal-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.tpfinal.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)


  tags = {
    Name = "tpfinal-private-${count.index + 1}"
  }
}

// PASARELLE INTERNET
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.tpfinal.id

  tags = {
    Name = "tpfinal-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.tpfinal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "tpfinal-rtb-public"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.tpfinal.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "tpfinal-rtb-private"
  }
}

// TABLES DE ROUTAGE

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

// GROUPE DE SECURITE

resource "aws_security_group" "all-access" {
  name        = "all-access"
  description = "Allow SSH, HTTP, HTTPS, and some ports"
  vpc_id      = aws_vpc.tpfinal.id

  // Regles entrantes

  //SSH
  ingress {

    description = "SSH"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  //HTTP
  ingress {
    description = "HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PORT-BACKEND"
    from_port   = "8585"
    to_port     = "8585"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Portainer"
    from_port   = "9000"
    to_port     = "9000"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "JellyFish"
    from_port   = "8096"
    to_port     = "8096"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS / Traefik"
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }



}




// Création d’une paire de clés

resource "aws_key_pair" "tpfinal_key" {
  key_name   = "tpfinal-keypair"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096

}

// Création des instances

resource "local_file" "cluster_keypair" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "${path.module}/tpfinal-keypair.pem"
}

variable "ami_id" {
  type        = string
  description = "Id de l'AMI de l'instance"
  default     = "ami-084568db4383264d4"
}

variable "instance_type" {
  type        = string
  description = "Type de l'instance EC2"
  default     = "t3.large"
}

resource "aws_instance" "tpfinal_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id                   = aws_subnet.public_subnets[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.all-access.id]

  key_name = aws_key_pair.tpfinal_key.key_name

  tags = {
    Name = "tpfinal_instance"
  }

  user_data = file("${path.module}/user-data.sh")

}

output "web_server_public_ip" {
  description = "Adresse IP publique"
  value       = try(aws_instance.tpfinal_instance.public_ip, "")
}

