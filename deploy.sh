#!/usr/bin/env bash
set -e

function createNodeGroups {
    ACTION=$1
    read -p "Are you sure you want to $ACTION NODES in the CLUSTER ${CLUSTER_NAME} in REGION ${AWS_REGION}? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        ######################### GPU NODES #########################
        instance_json=$(python -c 'import sys, yaml, json; json.dump(yaml.safe_load(sys.stdin), sys.stdout, indent=4)' <instance_list.yaml)

        length=$(echo $instance_json | jq '.instances | length')
        for ((i = 0; i < $length; i++)); do
            export FAMILY=$(echo $instance_json | jq -r ".instances[$i].family")
            export SPOT_PRICE=$(echo $instance_json | jq -r ".instances[$i].spot_price")
            export NODEGROUP_TYPE=$(echo $instance_json | jq -r ".instances[$i].nodegroup_type")
            export DESIRED_CAPACITY=$(echo $instance_json | jq -r ".instances[$i].desiredCapacity")

            echo "FAMILY: $FAMILY"
            echo "SPOT_PRICE: $SPOT_PRICE"
            echo "NODEGROUP_TYPE: $NODEGROUP_TYPE"
            echo "DESIRED_CAPACITY: $DESIRED_CAPACITY"

            # Create nodeGroups for the cluster
            if [ "$ACTION" == "create" ]; then
                envsubst <nodeGroups_gpu_$type.yaml | eksctl create nodegroup -f -
            elif [ "$ACTION" == "delete" ]; then
                envsubst <nodeGroups_gpu_$type.yaml | eksctl delete nodegroup --approve -f -
            fi

        done
        ######################### CPU NODES #########################
        if [ "$ACTION" == "create" ]; then
            envsubst <nodeGroups_cpu_workers.yaml | eksctl create nodegroup -f -
        elif [ "$ACTION" == "delete" ]; then
            envsubst <nodeGroups_cpu_workers.yaml | eksctl delete nodegroup --approve -f -
        fi
    fi
}

function createCluster {
    read -p "Are you sure you want to CREATE a CLUSTER ${CLUSTER_NAME} in REGION ${AWS_REGION}? (y/n): " confirm
    if [[ $confirm == [Yy] ]]; then
        # Create cluster
        envsubst <cluster.yaml | eksctl create cluster -f -

        # Create ASG policy
        envsubst <policy.template.json >policy.json
        aws iam create-policy --policy-name ${AWS_POLICY_NAME} --policy-document file://policy.json

        # Get cluster credentials
        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
        kubectl cluster-info

        # Install eb-csi addons
        kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
        kubectl get pods -n kube-system | grep ebs-csi

        # Metricts server
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        kubectl get pods -n kube-system | grep metrics-server

        # Install autoscaler
        envsubst <asg-autodiscover.yaml | kubectl apply -f -
        kubectl get pods --namespace=kube-system | grep autoscaler

        # Update aws-auth
        kubectl get configmap aws-auth -n kube-system -o yaml >aws-auth.yaml
        echo "Update manually aws-auth.yaml, use as example mapUsers.yaml"
        echo "kubectl apply -f aws-auth.yaml"
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
export PREFIX_NAME="geocompas"
export ENVIRONMENT=$1
export AWS_REGION=$2
export ACTION=$3
export AWS_PARTITION="aws"
export CLUSTER_NAME="${PREFIX_NAME}-k8s-${ENVIRONMENT}"
export KUBERNETES_VERSION="1.29"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export AWS_POLICY_NAME=${PREFIX_NAME}-k8s_${ENVIRONMENT}-${AWS_REGION}
export AWS_POLICY_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${AWS_POLICY_NAME}

export AWS_AVAILABILITY_ZONE="us-east-1a"

echo "Make sure you have created a Key pairs, called: k8s-sam-${AWS_REGION}..."

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
