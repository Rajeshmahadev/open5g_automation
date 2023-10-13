# Provider

provider "aws" {
  region = "us-east-1"
}

# VPC 1
# You can add more resources specific to each VPC here, such as subnets, security groups, and route tables.

resource "aws_vpc" "vpc1" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "open5gs-VPC1-core-02"
  }
}

# Define Subnets
resource "aws_subnet" "subnet_vpc1_1" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a" # Change to your desired availability zone
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_vpc1_1"
  }
}

#InternetGateway creation
resource "aws_internet_gateway" "gw1" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "open5g-IGW-01"
  }
}
resource "aws_route_table" "Public-RTC1" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw1.id
  }

  tags = {
    Name = "Public-RTC-01"
  }
}

#Route table association with public subnet
resource "aws_route_table_association" "public-association1" {
  subnet_id      = aws_subnet.subnet_vpc1_1.id
  route_table_id = aws_route_table.Public-RTC1.id
}

#SecurityGroup Creation

resource "aws_security_group" "SG1" {
  name        = "allow_all_traffic"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "TLS from VPC"
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
    Name = "open5gs-SG1-public"
  }
}
# First Key Pair
resource "aws_key_pair" "tf-key-pair-1" {
  key_name   = "tf-key-pair-1"
  public_key = tls_private_key.rsa1.public_key_openssh
}

resource "tls_private_key" "rsa1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "tf-key-1" {
  content  = tls_private_key.rsa1.private_key_pem
  filename = "tf-key-pair-1"
}


#Creating EC2 instant in public subnet2

resource "aws_instance" "ec2-web1" {
  ami                         = "ami-007855ac798b5175e"
  instance_type               = "t2.medium"
  availability_zone           = "us-east-1a"
  key_name                    = "tf-key-pair-1"
  vpc_security_group_ids      = ["${aws_security_group.SG1.id}"]
  subnet_id                   = aws_subnet.subnet_vpc1_1.id
  associate_public_ip_address = true
  #user_data                  = file("master_node.sh")

  root_block_device {
    volume_size = "50"
    volume_type = "io1"
    iops        = "300"

  }

  tags = {
    Name = "master-node1"
  }
}
resource "null_resource" "null-res-01" {
  # Provisioner block defines when this null_resource should be created or recreated.
  # triggers = {
  #   instance_id = aws_instance.ec2-web1.id
  # }
  connection {
    type        = "ssh"
    host        = aws_instance.ec2-web1.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa1.private_key_pem
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      file("${path.module}/cloud_init.sh")
    ]
  }
  depends_on = [aws_instance.ec2-web1]
}

terraform {
  backend "s3" {
    bucket         = "my-tf-test-bucket-open5gs-core-automation"
    dynamodb_table = "state-lock-core"
    key            = "global/mystate/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
