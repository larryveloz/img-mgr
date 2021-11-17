output "vpc_id" {
  value = aws_vpc.common_vpc.id
}

output "public_subnets_id" {
  value = aws_subnet.public_subnets.*.id
}

output "private_subnets_id" {
  value = aws_subnet.private_subnets.*.id
}

output "public_route_table" {
  value = aws_route_table.common_vpc_ig.id
}

output "private_route_table" {
  value = ["${aws_route_table.common_vpc_nat.*.id}"]
}
