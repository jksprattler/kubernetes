#!/bin/bash
# Jenna Sprattler | SRE Kentik | 2023-06-06
# Sets kubectl context, context and provided cluster name must match
# Performs checks on status of cluster and all pods

# Check if required positional parameters are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <cluster-name> <region> <aws-profile>"
    exit 1
fi

# Set variables for EKS cluster
cluster_name="$1"
region="$2"
aws_profile="$3"

# Set the current context to the cluster name
kubectl config use-context "$cluster_name"
echo "########################################################"

# Display addresses of the master and services
kubectl cluster-info
echo "########################################################"

# Check the control plane version
control_plane_version=$(kubectl version --short)
echo -e "Control Plane Version:\n$control_plane_version"
echo "########################################################"

# Check EKS cluster version and status
cluster_version=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
cluster_status=$(aws eks describe-cluster --name "$cluster_name" --region "$region" \
    --profile "$aws_profile" \
    --query 'cluster.{Status: status}' \
    --output json | jq -r '.Status')
echo "Cluster Version: $cluster_version"
echo "Cluster Status: $cluster_status"
echo "########################################################"

# Check available supported EKS versions for upgrade
# Choose the next code train version in line to install
echo "Available EKS versions:"
eksctl version -o json | jq -r '.EKSServerSupportedVersions[]'
echo "########################################################"

# Check cluster nodes
kubectl get nodes
echo "########################################################"

# Display custom columns for pods with node, pod, namespace, status, and age
kubectl get pods --all-namespaces \
    -o custom-columns='NODE:spec.nodeName,POD:metadata.name,NAMESPACE:metadata.namespace,STATUS:status.phase,AGE:metadata.creationTimestamp' \
    | sort -k1,1 -k2
echo "########################################################"

# Get all pods in the cluster
pods=$(kubectl get pods --all-namespaces \
    -o jsonpath="{range .items[*]}{.metadata.namespace} {.metadata.name}{'\n'}{end}")

# Count the total number of pods
total_pods=$(echo "$pods" | wc -l)
echo "Total number of pods running: $total_pods"
echo "########################################################"

# Loop over each pod and describe
while read -r pod; do
    pod_namespace=$(echo "$pod" | awk '{print $1}')
    pod_name=$(echo "$pod" | awk '{print $2}')

    echo "Checking pod: $pod_namespace/$pod_name"
    # Get the Node through Status for the pod
    node_status=$(kubectl describe pod "$pod_name" \
        --namespace "$pod_namespace" | awk '/Node:/,/Status:/')
    echo "$node_status"
    echo "########################################################"
done <<< "$pods"
