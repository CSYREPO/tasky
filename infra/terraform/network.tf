##############################################
# VPC and Networking for Tasky Environment
##############################################

data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

# --- Public Subnets (spread across AZs) ---
resource "aws_subnet" "public" {
  for_each = {
    "a" = var.public_subnets[0]
    "b" = var.public_subnets[1]
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = data.aws_availability_zones.available.names[tonumber(each.key == "a" ? 0 : 1)]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

# --- Private Subnets (spread across AZs) ---
resource "aws_subnet" "private" {
  for_each = {
    "a" = var.private_subnets[0]
    "b" = var.private_subnets[1]
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[tonumber(each.key == "a" ? 0 : 1)]

  tags = {
    Name                              = "${var.project}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# --- NAT Gateway ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id

  tags = {
    Name = "${var.project}-nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

# --- Route Tables ---
## Public route table (Internet access)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project}-public-rt" }
}

## Private route table (NAT access)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = { Name = "${var.project}-private-rt" }
}

# --- Route Table Associations ---
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

