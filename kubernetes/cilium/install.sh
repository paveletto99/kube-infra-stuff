#!/usr/bin/env bash
set -euo pipefail

kind create cluster --config kubernetes/kind/multi-cluster-01-kind-config.yml
kind create cluster --config kubernetes/kind/multi-cluster-02-kind-config.yml
export CLUSTER1=kind-alliance-sector-01
export CLUSTER2=kind-alliance-sector-02

cilium install --context $CLUSTER1 --set cluster.name=kind-alliance-sector-01 --set cluster.id=1 --set encryption.enabled=true --set encryption.type=wireguard --helm-set "l7Proxy=false"
cilium status --context $CLUSTER1 --wait

cilium install --context $CLUSTER2 --set cluster.name=kind-alliance-sector-02 --set cluster.id=2 --set encryption.enabled=true --set encryption.type=wireguard --helm-set "l7Proxy=false"
kubectl --context=$CLUSTER1 get secret -n kube-system cilium-ca -o yaml | kubectl --context $CLUSTER2 replace --force -f -

cilium status --context $CLUSTER2 --wait

# ✨ Enable clustermesh on both clusters

cilium clustermesh enable --service-type NodePort --context $CLUSTER1
cilium clustermesh enable --service-type NodePort --context $CLUSTER2
cilium clustermesh status --context $CLUSTER1
cilium clustermesh status --context $CLUSTER2

# ✨ Connect clusters
cilium clustermesh connect --context $CLUSTER1 --destination-context $CLUSTER2
cilium clustermesh status --context $CLUSTER2 --wait
cilium clustermesh status --context $CLUSTER1 --wait

# ✨ Deploy global service example

kubectl apply --context $CLUSTER1 -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/cluster1.yaml
kubectl apply --context $CLUSTER1 -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/global-service-example.yaml
kubectl apply --context $CLUSTER2 -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/cluster2.yaml
kubectl apply --context $CLUSTER2 -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/clustermesh/global-service-example.yaml

kubectl --context $CLUSTER1 exec -ti deployment/x-wing -- curl rebel-base
kubectl --context $CLUSTER2 exec -ti deployment/tie-fighter -- curl rebel-base