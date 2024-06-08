#!/usr/bin/env bash
set -e
mkdir -p tmp
function createNodeGroups {
    ACTION=$1
    read -p "Are you sure you want to $ACTION NODES in the CLUSTER ${CLUSTER_NAME} in REGION ${AWS_REGION}? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        ######################### GPU NODES #########################
        instance_json=$(python3 -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout, indent=4)' <instance_list.yaml)

        length=$(echo $instance_json | jq '.instances | length')
        for ((i = 0; i < $length; i++)); do
            export FAMILY=$(echo $instance_json | jq -r ".instances[$i].family")
            export SPOT_PRICE=$(echo $instance_json | jq -r ".instances[$i].spot_price")
            export NODEGROUP_TYPE=$(echo $instance_json | jq -r ".instances[$i].nodegroup_type")
            export DESIRED_CAPACITY_ONDEMAND=$(echo $instance_json | jq -r ".instances[$i].desiredCapacity_ondemand")
            export DESIRED_CAPACITY_SPOT=$(echo $instance_json | jq -r ".instances[$i].desiredCapacity_spot")
            echo "FAMILY: $FAMILY"
            echo "SPOT_PRICE: $SPOT_PRICE"
            echo "NODEGROUP_TYPE: $NODEGROUP_TYPE"
            echo "DESIRED_CAPACITY_ONDEMAND: $DESIRED_CAPACITY_ONDEMAND"
            echo "DESIRED_CAPACITY_SPOT: $DESIRED_CAPACITY_SPOT"
            # Create nodeGroups for the cluster
            # envsubst <nodeGroups.yaml > tmp/nodeGroups.yaml
            if [ "$ACTION" == "create" ]; then
                envsubst <nodeGroups.yaml | eksctl create nodegroup -f -
            elif [ "$ACTION" == "delete" ]; then
                envsubst <nodeGroups.yaml | eksctl delete nodegroup --approve -f -
            fi
        done
    fi
}

function createCluster {
    read -p "Are you sure you want to CREATE a CLUSTER ${CLUSTER_NAME} in REGION ${AWS_REGION}? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        # Create cluster
        # envsubst <cluster.yaml | eksctl create cluster -f -

        # Create ASG policy
        # envsubst <policy.template.json > tmp/policy.json
        # aws iam create-policy --policy-name ${AWS_POLICY_NAME} --policy-document file://tmp/policy.json

        # # Get cluster credentials
        # aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
        # kubectl cluster-info

        # # Install eb-csi addons
        # kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
        # kubectl get pods -n kube-system | grep ebs-csi

        ### Metricts server
        # kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        # kubectl get pods -n kube-system | grep metrics-server

        ### Install autoscaler
        # envsubst <asg-autodiscover.yaml | kubectl apply -f -
        # kubectl get pods --namespace=kube-system | grep autoscaler

        ### Instaling ingress-nginx and cert-manager
        # helm repo add jetstack https://charts.jetstack.io
        # helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        # helm repo update
        # helm install \
        # cert-manager jetstack/cert-manager \
        # --namespace cert-manager \
        # --create-namespace \
        # --version v1.15.0 \
        # --set crds.enabled=true
        helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
        kubectl get pods -n cert-manager
        kubectl get pods -n ingress-nginx

        ### Update aws-auth
        # kubectl get configmap aws-auth -n kube-system -o yaml >aws-auth.yaml
        # echo "Update manually aws-auth.yaml, use as example mapUsers.yaml"
        # echo "kubectl apply -f aws-auth.yaml"
    fi

}

function deleteCluster {
    read -p "Are you sure you want to DELETE the CLUSTER ${CLUSTER_NAME} in REGION ${AWS_REGION}? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        eksctl delete cluster --region=${AWS_REGION} --name=${CLUSTER_NAME}
        aws iam delete-policy --policy-arn ${AWS_POLICY_ARN}
    fi
}

### Main
export ENVIRONMENT=$1
export ACTION=$2

export AWS_REGION="us-east-1"
export AWS_AVAILABILITY_ZONE="us-east-1a"
export PREFIX_NAME="osm-us"
export AWS_PARTITION="aws"
export CLUSTER_NAME="${PREFIX_NAME}-k8s-${ENVIRONMENT}"
export KUBERNETES_VERSION="1.29"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export AWS_POLICY_NAME=${PREFIX_NAME}-k8s_${ENVIRONMENT}-${AWS_REGION}
export AWS_POLICY_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_POLICY_NAME}

ACTION=${ACTION:-default}
if [ "$ACTION" == "create_cluster" ]; then
    createCluster
elif [ "$ACTION" == "delete_cluster" ]; then
    deleteCluster
elif [ "$ACTION" == "create_nodes" ]; then
    # Create GPU nodes
    createNodeGroups create
elif [ "$ACTION" == "delete_nodes" ]; then
    # Delete GPU nodes
    createNodeGroups delete
else
    echo "The action is unknown."
fi
