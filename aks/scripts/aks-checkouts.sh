#!/bin/bash
# Jenna Sprattler | SRE Kentik | 17-05-2023
# Sets kubectl context, context and provided cluster name must match
# Performs checks on status of cluster and all pods

# Check if required positional parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <resource-group> <cluster-name>"
    exit 1
fi

# Set variables for AKS cluster
resource_group="$1"
cluster_name="$2"

# Set the current context to the cluster name
kubectl config use-context "$cluster_name"
echo "########################################################"

# Display addresses of the master and services
kubectl cluster-info
echo "########################################################"

# Check the control plane version and available upgrade
az aks get-upgrades --resource-group "$resource_group" \
    --name "$cluster_name" --output table
echo "########################################################"

# Check AKS cluster status
az aks show --resource-group "$resource_group" \
    --name "$cluster_name" --output table
echo "########################################################"

# List node pools
az aks nodepool list --resource-group "$resource_group"  \
    --cluster-name "$cluster_name" --output table
echo "########################################################"

# Check cluster nodes
kubectl get nodes
echo "########################################################"

# Get all pods in the cluster
pods=$(kubectl get pods --all-namespaces \
    --output=jsonpath="{range .items[*]}{.metadata.namespace} {.metadata.name}{'\n'}{end}")

# Count the total number of pods
total_pods=$(echo "$pods" | wc -l)
echo "Total number of pods running: $total_pods"
echo "########################################################"

# Loop over each pod and describe
while read -r pod; do
    pod_namespace=$(echo "$pod" | awk '{print $1}')
    pod_name=$(echo "$pod" | awk '{print $2}')

    echo "Checking pod: $pod_namespace/$pod_name"
    # Get the Node Status and Events for the pod
    node_status=$(kubectl describe pod "$pod_name" \
        --namespace "$pod_namespace" | awk '/Node:/,/Status:/')
    echo "$node_status"
    echo "########################################################"
done <<< "$pods"
