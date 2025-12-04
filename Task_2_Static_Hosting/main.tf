# --- Data Sources (Fetch resources created in Task 1) ---

# Fetch the VPC ID
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["Janhvi_Singh_VPC"]
  }
}

# Fetch ALL Public Subnets in the VPC by looking for the property that maps public IPs
# Fetch the PUBLIC Route Table (with Internet Gateway)
data "aws_route_table" "public_rt" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "route.gateway-id"
    values = ["igw-*"]
  }
}

# Fetch all subnets in the VPC
data "aws_subnets" "all_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

locals {
  public_subnet_id = data.aws_subnets.all_subnets.ids[0]
}



# Fetch a suitable Amazon Linux AMI (Free Tier Compatible)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- Resource Creation ---

# 1. Security Group (SG) for basic infrastructure hardening
resource "aws_security_group" "web_sg" {
  name        = "Janhvi_Singh_Web_SG"
  description = "Allows HTTP/80 and limited SSH/22"
  vpc_id      = data.aws_vpc.selected.id

  # Inbound Rule 1: Allow HTTP (Port 80) from the Internet 
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to all internet access
  }

 
  ingress {
    description = "Allow restricted SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["49.43.114.137/32"]
  }

  # Outbound Rule: Allow all traffic out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Janhvi_Singh_Web_SG"
  }
}

# 2. User Data Script (Nginx installation and resume hosting)
data "cloudinit_config" "user_data" {
  gzip = false
  base64_encode = true
  
  part {
    filename     = "install_nginx.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install nginx -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "<h1>Janhvi Singh's Online Resume</h1>" | sudo tee /usr/share/nginx/html/index.html
    echo "<p>Deployed on Free Tier EC2 via Terraform and Nginx. Accessible via Public IP on Port 80.</p>" | sudo tee -a /usr/share/nginx/html/index.html
    EOF
  }
}

# 3. EC2 Key Pair (For potential SSH access)
resource "aws_key_pair" "deployer_key" {
  key_name   = "janhvi-ec2-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCx0KDYyduMboNGvKIogQR+N/Ak/p+uHYFKbkScf55VVwnue3RhHlqPft0otdSAyUi5rjCEarhiAXl5urw3jMzZipYMIXRHzdqynnJa3iNE8kXufQwXSFc4NrbLa5fig5SWsdpRIZcHFGWMm0n77pOLixrq2z/f7RqrVs7pbqyl3JfzcM++v0VV99rTeOk1sZb2E3mKszLxx2r0RMlM3NmU+iJbx/gFb/oKymldb6CbCWP7OKN808SU1eVgPuzS+VtpbnWLKR6/YCXg4vZYYLHmV9pxQp5qSAiF4mz3b2nfBfN0Hs354TriBr6MmpgzDxrLhDrGG171D3bl0XU8tQsKuTz0WvHWuiBsmOr/f2G9vw61e2ks4L6bo+LgcxnBEdNayp8DaxoROX6z/lGdPlgqZtf32Z1U7KjFd7asO5hSlgT0pTih3EsvbnrAbhqDGClMFl6LnJtl+k9UNHYdHdXG2Bj2YOHWwecLGFtvgbGQQ0Wb9Quupa+rXj++Tqf0rv73tURWBO2eJMwXRWLQ4eGakLOo7SCI0X+F+CGAAizbTBnXak66iNglU8Xc+sCEVxMv9Z2YN62/VnRBifnYiUNhxAdNpLq34k0IfW92a9h32GjfeA4xILF2yGY5ADEsOfeIfD10VMYoalJE6suRqn/49RZ+iuaijJGjsrg6ACq6bw== janhv@janhvi"
}

# 4. EC2 Instance Launch (Free Tier t2.micro)
resource "aws_instance" "web_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"             
  subnet_id              = local.public_subnet_id  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer_key.key_name
  
  associate_public_ip_address = true
  
  user_data_base64 = data.cloudinit_config.user_data.rendered
  
  tags = {
    Name = "Janhvi_Singh_Resume_EC2"
  }
}


# --- Outputs (Needed for Deliverables) ---
output "website_url" {
  description = "The Public IP of the Static Website"
  value       = aws_instance.web_instance.public_ip
}