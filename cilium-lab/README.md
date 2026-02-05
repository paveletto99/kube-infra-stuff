# Cilium Lab

Windows 11
 └── WSL2 (Ubuntu/Debian)
      └── Lima
           └── Debian VM
## Pre-requisites

```shell
sudo apt update
sudo apt install -y \
  curl \
  wget \
  git \
  build-essential \
  qemu-system \
  uidmap \
  fuse3
```

Install Lima

QEMU permissions on Linux

```shell
sudo usermod -aG kvm $USER
newgrp kvm
```


## Setup Instructions

```shell
limactl create --name k3s-cilium ./k3s-cilium.yaml
limactl start k3s-cilium
limactl shell k3s-cilium
```

## Accessing the K3s Cluster

```shell
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes -o wide
kubectl get pods -A
cilium status
cilium connectivity test
```

## Hubble Access

```shell
cilium hubble enable


# Enable UI
cilium hubble enable --ui

#
cilium status --wait

# UI (temp)
kubectl -n kube-system port-forward svc/hubble-relay 4245:80

# UI (background)
kubectl -n kube-system port-forward svc/hubble-relay 4245:80 >/tmp/hubble-relay.pf.log 2>&1 &
echo $! > /tmp/hubble-relay.pf.pid

# Status
hubble status

# Observe
hubble observe

```

Hubble UI from host

Hubble UI is HTTP; easiest is another port-forward:

Inside VM:
```shell
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```

From your host browser open:

`http://localhost:12000`


## Copy host folder into VM

```shell
# from VM
sudo mkdir /mnt/workspace
sudo chmod 777 /mnt/workspace/
# from host
limactl copy /home/pobo/workspace/kube-infra-stuff k3s-ebpf:/mnt/workspace/
```

