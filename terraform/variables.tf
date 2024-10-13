variable "db_name" {
  description = "Name of the PostgreSQL DB"
  type        = string

}

variable "db_username" {
  description = "Username for PostgreSQL DB"
  type        = string
}

variable "db_password" {
  description = "Pass for PostgreSQL DB"
  type        = string
  sensitive   = true
}

variable "ec2_key_name" {
  description = "Name of the EC2 keypair"
  type        = string
}
