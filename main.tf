# Provider

provider "aws" {
  region = "us-east-1"
}

# VPC 3
resource "aws_vpc" "vpc3" {
  cidr_block       = "10.2.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "open5gs-VPC3"
  }
}

resource "aws_subnet" "subnet_vpc3_1" {
  vpc_id                  = aws_vpc.vpc3.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "us-east-1c" # Change to your desired availability zone
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_vpc3_1"
  }
}

resource "aws_internet_gateway" "gw3" {
  vpc_id = aws_vpc.vpc3.id

  tags = {
    Name = "open5g-IGW-03"
  }
}

resource "aws_route_table" "Public-RTC3" {
  vpc_id = aws_vpc.vpc3.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw3.id
  }

  tags = {
    Name = "Public-RTC-03"
  }
}

resource "aws_route_table_association" "public-association3" {
  subnet_id      = aws_subnet.subnet_vpc3_1.id
  route_table_id = aws_route_table.Public-RTC3.id
}


#SecurityGroup Creation

resource "aws_security_group" "SG3" {
  name        = "allow_all_traffic"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.vpc3.id

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
    Name = "open5gs-SG3-public"
  }
}

# key pair creation

resource "aws_key_pair" "tf-key-pair" {
  key_name   = "tf-key-pair"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "tf-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tf-key-pair"
}

resource "aws_instance" "ec2-web3" {
  ami                         = "ami-007855ac798b5175e"
  instance_type               = "t2.medium"
  availability_zone           = "us-east-1c"
  key_name                    = "tf-key-pair"
  vpc_security_group_ids      = ["${aws_security_group.SG3.id}"]
  subnet_id                   = aws_subnet.subnet_vpc3_1.id
  associate_public_ip_address = true
  #user_data                  = file("master_node.sh")

  root_block_device {
    volume_size = "50"
    volume_type = "io1"
    iops        = "300"

  }

  tags = {
    Name = "master-node3"
  }
}

resource "null_resource" "null-res-03" {
  # Provisioner block defines when this null_resource should be created or recreated.
  # Uncomment and modify the triggers block if necessary.
  # triggers = {
  #   instance_id = aws_instance.ec2-web1.id
  # }

  # Define the connection details for SSH.
  connection {
    type        = "ssh"
    host        = aws_instance.ec2-web3.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
  }

  # Define the provisioner for remote execution.
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      file("${path.module}/cloud_init3.sh")
    ]
  }

  # Specify that this null_resource depends on the completion of aws_instance.ec2-web3.
  depends_on = [aws_instance.ec2-web3]
}


terraform {
  backend "s3" {
    bucket = "my-tf-test-bucket-open5gs-monitoring-automation"
    dynamodb_table = "state-lock-monitoring"
    key    = "global/mystate/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}
