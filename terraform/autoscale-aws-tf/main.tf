provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "eu_north_1a" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a"
  cidr_block              = "10.0.1.0/24"
}

resource "aws_subnet" "eu_north_1b" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1b"
  cidr_block              = "10.0.2.0/24"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "eu_north_1a" {
  subnet_id      = aws_subnet.eu_north_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "eu_north_1b" {
  subnet_id      = aws_subnet.eu_north_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

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

  # temp for bugfix
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Everything
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.eu_north_1a.id, aws_subnet.eu_north_1b.id]
}

resource "aws_lb_target_group" "main" {
  vpc_id      = aws_vpc.main.id
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
}

resource "aws_launch_template" "main" {
  image_id      = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  placement {
    availability_zone = "eu-north-1"
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.ec2_key_name
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y nginx

              sudo add-apt-repository ppa:longsleep/golang-backports -y
              sudo apt-get install golang-go -y

              sudo git clone https://github.com/tonygitcoder/cicd-course-go-demo.git
              cd cicd-course-go-demo
              sudo go build -o golang-demo -buildvcs=false
              sudo chmod +x golang-demo
              cat <<EOF2 > /etc/nginx/sites-available/default
              server {
                listen 80;

                location / {
                    proxy_pass http://localhost:8080;
                }
              }
              EOF2
              sudo systemctl restart nginx
              ./golang-demo &
              EOF
  )
}

resource "aws_autoscaling_group" "main" {
  min_size            = 1
  desired_capacity    = 1
  max_size            = 2
  target_group_arns   = [aws_lb_target_group.main.arn]
  vpc_zone_identifier = [aws_subnet.eu_north_1a.id, aws_subnet.eu_north_1b.id]

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
