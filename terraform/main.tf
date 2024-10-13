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

resource "aws_subnet" "eu_north_1c" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1c"
  cidr_block              = "10.0.3.0/24"
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

resource "aws_route_table_association" "eu_north_1c" {
  subnet_id      = aws_subnet.eu_north_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_db_subnet_group" "main" {
  name = "golang-demo-db-subnet-group"
  subnet_ids = [
    aws_subnet.eu_north_1a.id,
    aws_subnet.eu_north_1b.id,
    aws_subnet.eu_north_1c.id
  ]
}

resource "aws_db_parameter_group" "postgres" {
  name   = "golang-demo-db-parameter-group"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  # Postgres
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "golang-demo-db"

  engine            = "postgres"
  engine_version    = "16.3" # Default on AWS when I was creating in console
  instance_class    = "db.t4g.micro"
  allocated_storage = 20

  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  parameter_group_name = aws_db_parameter_group.postgres.name

  apply_immediately = true # TODO: remove after testing
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Everything
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "main" {
  ami                    = "ami-08eb150f611ca277f"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.eu_north_1a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  key_name = var.ec2_key_name

  depends_on = [aws_db_instance.postgres]

  # Without this flag I was getting an 'in-place' for instance in 'terrafor plan'
  # but then AWS would just delete the instance and create new
  # and my public dns output didn't match the real one
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/server_config.sh", {
    DB_ENDPOINT = aws_db_instance.postgres.address,
    DB_PORT     = 5432,
    DB_NAME     = var.db_name,
    DB_USER     = var.db_username,
    DB_PASSWORD = var.db_password
  })

  lifecycle {
    # To decrease restart time by the time it takes user_data to run 
    create_before_destroy = true
  }
}

# Use it to connect via ssh and use it in browser/curl
output "instance_public_dns" {
  value = aws_instance.main.public_dns
}
