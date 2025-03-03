data "aws_availability_zones" "available" {
  state = "available"
}

data "external" "subnet_details" {
  program = ["python", "${path.module}/scripts/subnet_details.py"]

  query = {
    vpc_cidr                      = var.vpc_cidr
    number_of_azs                 = var.number_of_azs
    min_routable_subnet_ip_count  = var.min_routable_subnet_ip_count
  }
}

locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, var.number_of_azs)
  vpc_ep_sg_ingress_cidr_blocks = concat([var.vpc_cidr], [])
}
# It requires three arguments:
# 1. 'prefix' - The original CIDR block to be subdivided.
# 2. 'newbits' - The number of additional bits to extend the subnet mask.
# 3. 'netnum' - The numerical index of the subnet being created, starting from 0.
#
# The list comprehension '[for i in range(var.number_of_azs) : cidrsubnet(...)]' generates a list by iterating ove
# For each number 'i' in the sequence 'range(var.number_of_azs)', which generates numbers from 0 to 'var.number_of_
# the 'cidrsubnet' function is called to produce an element of the list representing a subnet's CIDR block.
#
# Determine how many bits to add to the CIDR mask to get the desired number of subnets
routable_subnet_cidr_blocks = split(",", data.external.subnet_details.result["routable_subnet_cidrs"])
tgw_subnet_cidrs            = split(",", data.external.subnet_details.result["tgw_subnet_cidrs"])

services = [
    "ec2",
    "sqs",
    "sns",
    "events",
    "ecr.dkr",
    "ecr.api",
    "sts",
    "logs",
    "ssm",
    "ssmmessages",
]
