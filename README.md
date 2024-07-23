# EKS Cluster for osm-sandbox

# Configure manually the existing VPC

### Get VPC ids from aws 

```sh
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0463def14f555a7ed" --query "Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}"
```

- Results

```json
  {
        "ID": "subnet-0f8836c96b7d3305f",
        "CIDR": "172.31.0.0/20",
        "AZ": "us-east-1d",
        "Public": true
    },
    {
        "ID": "subnet-0920a1dff5c03103b",
        "CIDR": "172.31.32.0/20",
        "AZ": "us-east-1c",
        "Public": true
    },
    {
        "ID": "subnet-049a6317b90706776",
        "CIDR": "172.31.16.0/20",
        "AZ": "us-east-1b",
        "Public": true
    },
    {
        "ID": "subnet-02c7bfb3450e3cb14",
        "CIDR": "172.31.80.0/20",
        "AZ": "us-east-1a",
        "Public": true
    },
    {
        "ID": "subnet-065d9574978041652",
        "CIDR": "172.31.48.0/20",
        "AZ": "us-east-1e",
        "Public": true
    },
    {
        "ID": "subnet-0b7faf7a4a01e03ff",
        "CIDR": "172.31.64.0/20",
        "AZ": "us-east-1f",
        "Public": true
    },
```
Update the values in cluster.yaml.


# Create venv 

```sh
python3 -m venv eks_cluster
source eks_cluster/bin/activate
pip install pyyaml
```

## Deploy  cluster

```sh
./deploy.sh staging create_cluster
```

## Deploy nodes

```sh
./deploy.sh staging create_nodes
```

