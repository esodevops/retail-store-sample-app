variable "vpc_name" { type = string }
variable "vpc_cidr" { type = string }
variable "vpc_azs" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "enable_nat_gateway" { type = bool }
variable "map_public_ip_on_launch" { type = bool }
variable "tags" { type = map(string) }
