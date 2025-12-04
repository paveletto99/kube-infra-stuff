#!/bin/sh

kubectl create rolebinding default-workflow-rb \
  --clusterrole=argo-workflow \
  --serviceaccount=argo:default \
  -n argo 2>/dev/null || \
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-workflow-rb
  namespace: argo
subjects:
- kind: ServiceAccount
  name: default
  namespace: argo
roleRef:
  kind: ClusterRole
  name: argo-workflow
  apiGroup: rbac.authorization.k8s.io
EOF

echo "-------------------------------------------"

kubectl create rolebinding default-admin-rb \
  --clusterrole=admin \
  --serviceaccount=argo:default \
  -n argo