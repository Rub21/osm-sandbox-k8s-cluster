



aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0463def14f555a7ed" --query "Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}"


subnet-0f8836c96b7d3305f
subnet-065d9574978041652
subnet-0b7faf7a4a01e03ff
subnet-0920a1dff5c03103b
subnet-02c7bfb3450e3cb14 