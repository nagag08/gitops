#!/usr/bin/env bash

# This script creates a fleet of Kubernetes clusters using kind.

# Copyright 2024 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Prerequisites
# - docker v25.0
# - kind v0.22
# - kubectl v1.29

set -o errexit
set -o pipefail
addcerts() {
    docker cp ~/Downloads/n.pem $1:/usr/local/share/ca-certificates/n.crt
    docker cp ~/Downloads/Z.pem $1:/usr/local/share/ca-certificates/z.crt
    docker exec $1 update-ca-certificates
    docker restart $1
    sleep 5
    curl https://asia-south1-docker.pkg.dev/v2/k8s-artifacts-prod/images/ingress-nginx/kube-webhook-certgen/manifests/v1.6.2
}
repo_root=$(git rev-parse --show-toplevel)
mkdir -p "${repo_root}/bin"

CLUSTER_VERSION="${CLUSTER_VERSION:=v1.29.2}"

CLUSTER_HUB="flux-hub"
echo "INFO - Creating cluster ${CLUSTER_HUB}"

kind create cluster --name "${CLUSTER_HUB}" \
--image "kindest/node:${CLUSTER_VERSION}" \
--wait 5m

dockerid=$(docker ps --format "table {{.ID}}\t{{.Names}}" | grep $CLUSTER_HUB | awk '{print $1}')
addcerts $dockerid

CLUSTER_STAGING="flux-staging"
echo "INFO - Creating cluster ${CLUSTER_STAGING}"

kind create cluster --name "${CLUSTER_STAGING}" \
--image "kindest/node:${CLUSTER_VERSION}" \
--wait 5m --config kind-c2.yaml

dockerid=$(docker ps --format "table {{.ID}}\t{{.Names}}" | grep $CLUSTER_STAGING | awk '{print $1}')
addcerts $dockerid

CLUSTER_PRODUCTION="flux-production"
echo "INFO - Creating cluster ${CLUSTER_PRODUCTION}"

kind create cluster --name "${CLUSTER_PRODUCTION}" \
--image "kindest/node:${CLUSTER_VERSION}" \
--wait 5m --config kind-c3.yaml

dockerid=$(docker ps --format "table {{.ID}}\t{{.Names}}" | grep $CLUSTER_PRODUCTION | awk '{print $1}')
addcerts $dockerid

# echo "INFO - Creating kubeconfig secrets in the hub cluster"
# echo "----------------------"
# echo "Run update certs script"
# echo "----------------------"
# read -p "Press Enter to continue..."
# kubectl config use-context "kind-${CLUSTER_HUB}"

kind get kubeconfig --internal --name ${CLUSTER_STAGING} > "${repo_root}/bin/staging.kubeconfig"
kubectl --context "kind-${CLUSTER_HUB}" create ns staging
kubectl --context "kind-${CLUSTER_HUB}" create secret generic -n staging cluster-kubeconfig \
--from-file=value="${repo_root}/bin/staging.kubeconfig"

kind get kubeconfig --internal --name ${CLUSTER_PRODUCTION} > "${repo_root}/bin/production.kubeconfig"
kubectl --context "kind-${CLUSTER_HUB}" create ns production
kubectl --context "kind-${CLUSTER_HUB}" create secret generic -n production cluster-kubeconfig \
--from-file=value="${repo_root}/bin/production.kubeconfig"

echo "INFO - Clusters created successfully"
