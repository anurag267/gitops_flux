output "vpc_id" {
  value = aws_vpc.vpc_private.id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_subnets_cidrs" {
  value = aws_subnet.private[*].cidr_block
}

output "tgw_subnet_ids" {
  value = aws_subnet.tgw[*].id
}

output "tgw_subnets_cidrs" {
  value = aws_subnet.tgw[*].cidr_block
}

variable "aws_region" {
    type        = string
    default     = "{{ cookiecutter.generic.aws_region }}"
}

variable "number_of_azs" {
    description = "A list of availability zones"
    type        = number
    default     = "{{ cookiecutter.generic.number_of_azs }}"
}

variable "vpc_name" {
    description = "Name for the VPC"
    default     = "{{ cookiecutter.generic.vpc_name }}"
}

variable "min_routable_subnet_ip_count" {
    description = "Name for the VPC"
    default     = "{{ cookiecutter.generic.min_routable_subnet_ip_count }}"
}
