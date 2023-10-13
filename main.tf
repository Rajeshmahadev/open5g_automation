# Provider

provider "aws" {
  region = "us-east-1"
}

# VPC 2
resource "aws_vpc" "vpc2" {
  cidr_block       = "10.1.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "open5gs-VPC2-ran"
  }
}

resource "aws_subnet" "subnet_vpc2_1" {
  vpc_id                  = aws_vpc.vpc2.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-east-1b" # Change to your desired availability zone
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_vpc2_1"
  }
}

resource "aws_internet_gateway" "gw2" {
  vpc_id = aws_vpc.vpc2.id

  tags = {
    Name = "open5g-IGW-02"
  }
}

resource "aws_route_table" "Public-RTC2" {
  vpc_id = aws_vpc.vpc2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw2.id
  }

  tags = {
    Name = "Public-RTC-02"
  }
}

resource "aws_route_table_association" "public-association2" {
  subnet_id      = aws_subnet.subnet_vpc2_1.id
  route_table_id = aws_route_table.Public-RTC2.id
}


#SecurityGroup Creation

resource "aws_security_group" "SG2" {
  name        = "allow_all_traffic"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.vpc2.id

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
    Name = "open5gs-SG2-public"
  }
}
# Second Key Pair
resource "aws_key_pair" "tf-key-pair-2" {
  key_name   = "tf-key-pair-2"
  public_key = tls_private_key.rsa2.public_key_openssh
}

resource "tls_private_key" "rsa2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "tf-key-2" {
  content  = tls_private_key.rsa2.private_key_pem
  filename = "tf-key-pair-2"
}


resource "aws_instance" "ec2-web2" {
  ami                         = "ami-007855ac798b5175e"
  instance_type               = "t2.medium"
  availability_zone           = "us-east-1b"
  key_name                    = "tf-key-pair-2"
  vpc_security_group_ids      = ["${aws_security_group.SG2.id}"]
  subnet_id                   = aws_subnet.subnet_vpc2_1.id
  associate_public_ip_address = true
  #user_data                  = file("master_node.sh")

  root_block_device {
    volume_size = "50"
    volume_type = "io1"
    iops        = "300"

  }

  tags = {
    Name = "master-node2"
  }
}

resource "null_resource" "null-res-02" {
  # Define when this null_resource should be created or recreated.
  # Uncomment and modify the triggers block if necessary.
  # triggers = {
  #   instance_id = aws_instance.ec2-web1.id
  # }

  # Define the connection details for SSH.
  connection {
    type        = "ssh"
    host        = aws_instance.ec2-web2.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.rsa2.private_key_pem
  }

  # Define the provisioner for remote execution.
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      file("${path.module}/cloud_init2.sh")
    ]
  }

  # Specify that this null_resource depends on the completion of aws_instance.ec2-web2.
  depends_on = [aws_instance.ec2-web2]
}


terraform {
  backend "s3" {
    bucket = "my-tf-test-bucket-open5gs-ran-automation"
    dynamodb_table = "state-lock-ran"
    key    = "global/mystate/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}
