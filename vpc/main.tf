resource "aws_vpc" "vpc_private" {
  cidr_block                = var.vpc_cidr
  enable_dns_support        = true
  enable_dns_hostnames      = true

  assign_generated_ipv6_cidr_block = var.ipv6_enabled

  tags = merge(
    var.tag_defaults,
    {
      Name = var.vpc_name
    }
  )
}

resource "aws_route_table_association" "tgw" {
  count          = var.number_of_azs
  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}

resource "aws_subnet" "private" {
  count                               = length(local.routable_subnet_cidr_blocks)
  vpc_id                              = aws_vpc.vpc_private.id
  cidr_block                          = local.routable_subnet_cidr_blocks[count.index]
  availability_zone                   = local.selected_azs[count.index % length(local.selected_azs)]
  assign_ipv6_address_on_creation     = var.ipv6_enabled
  ipv6_cidr_block                     = var.ipv6_enabled ? cidrsubnet(aws_vpc.vpc_private.ipv6_cidr_block, 8, count.index) : null

  tags = merge(
    var.tag_defaults,
    {
      Name = format("%s-%s-%d", var.vpc_name, "private-subnet", count.index + 1)
    }
  )
}

resource "aws_route_table_association" "private" {
  count          = var.number_of_azs
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_nat_gateway" "nat" {
  count             = var.number_of_azs
  allocation_id     = "" 
  subnet_id         = aws_subnet.private[count.index].id
  connectivity_type = "private"

  tags = merge(
    var.tag_defaults,
    {
      Name = format("%s-%s-%s-%d", var.vpc_name, var.aws_region, "private-rt", count.index + 1)
    }
  )
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.vpc_private.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = aws_route_table.private[*].id

  tags = merge(
    var.tag_defaults,
    {
      Name = format("%s-%s-%s", var.vpc_name, var.aws_region, "s3-vpc-endpoint")
    }
  )
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id = aws_vpc.vpc_private.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  route_table_ids = aws_route_table.private[*].id

  tags = merge(
    var.tag_defaults,
    {
      Name = format("%s-%s-%s", var.vpc_name, var.aws_region, "dynamodb-vpc-endpoint")
    }
  )
}

resource "aws_security_group" "vpc_endpoint_sg" {
  name = format("%s-%s-%s", var.vpc_name, var.aws_region, "vpc-endpoint-sg")
  description = format("%s-%s-%s", var.vpc_name, var.aws_region, "vpc-endpoint-sg")
  vpc_id = aws_vpc.vpc_private.id

  dynamic "ingress" {
    for_each = local.vpc_sg_ingress_cidr_blocks
  }
  dynamic "egress" {
    for_each = var.vpc_ep_sg_egress_cidr_blocks
    content {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [egress.value]
    }
  }
  tags = merge(
  var.tag_defaults,
  {
    Name = format("%s-%s-%s", var.vpc_name, var.aws_region, "vpc-endpoint-sg")
  }
  )
}

resource "aws_vpc_endpoint" "vpc_endpoints" {
  count             = length(local.services)
  vpc_id            = aws_vpc.vpc_private.id
  service_name      = "com.amazonaws.${var.aws_region}.${local.services[count.index]}"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private.*.id
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = merge(
    var.tag_defaults,
    {
      Name = format("%s-%s-%s-%s", var.vpc_name, var.aws_region, local.services[count.index], "vpc-endpoint")
    }
  )
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw" {
  subnet_ids         = aws_subnet.tgw[*].id
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.vpc_private.id
  tags = merge(
    var.tag_defaults,
    {
      Name = format("%s-%s-%s", var.vpc_name, var.aws_region, "tgw-attachment")
    }
  )
}

# {% if cookiecutter.generic.step == "step2" %}
resource "aws_route" "private" {
  count                     = var.number_of_azs
  route_table_id            = aws_route_table.private[count.index].id
  destination_cidr_block    = "0.0.0.0/0"
  vpc_peering_connection_id = var.tgw_id
}
# {% endif %}