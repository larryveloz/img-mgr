# Create a VPC
resource "aws_vpc" "common_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "larryveloz_VPC"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.common_vpc.id
  cidr_block              = "${var.public_subnet_cidrs[count.index]}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true
  tags = {
    Name = "larryveloz_public_subnet${count.index}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)
  vpc_id     = aws_vpc.common_vpc.id
  cidr_block              = "${var.private_subnet_cidrs[count.index]}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  tags = {
    Name = "larryveloz_private_subnet${count.index}"
  }
}

# Create IGW
resource "aws_internet_gateway" "common_vpc_ig" {
  vpc_id = aws_vpc.common_vpc.id
  tags = {
    Name = "larryveloz_igw"
  }
}

# Create a EIP
resource "aws_eip" "nat_gateway_eips" {
  count = 2
  vpc = true
}

# Create Nat Gateway
resource "aws_nat_gateway" "nat_gateways" {
  count = 2
  allocation_id = aws_eip.nat_gateway_eips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "larryveloz_natgw"
  }
  depends_on = [aws_internet_gateway.common_vpc_ig]
}

# Create a Route Table
resource "aws_route_table" "common_vpc_ig" {
  vpc_id = aws_vpc.common_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.common_vpc_ig.id
  }

  tags = {
    Name = "larryveloz_public_route_${terraform.workspace}"
  }
}

resource "aws_route_table_association" "common_vpc_ig" {
  count = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.common_vpc_ig.id
}

resource "aws_route_table" "common_vpc_nat" {
  count = 2
  vpc_id = aws_vpc.common_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateways[count.index].id
  }

  tags = {
    Name = "larryveloz_private_routes_(AZ${count.index})${terraform.workspace} "
  }
}

resource "aws_route_table_association" "nat_gateways" {
  count = 2
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.common_vpc_nat[count.index].id
}
