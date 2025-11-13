# kubernetes custom controller and kind setups with observability

- kube-rs
- kind
- skaffold
-

```shell
cargo upgrade -i allow && cargo update
```

## Install metric server on kind

```shell
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch -n kube-system deployment metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

## unix optimizations

```shell
sudo sysctl fs.inotify.max_user_instances=256
sudo sysctl fs.inotify.max_user_watches=524288

```

To make this change permanent, you can edit the /etc/security/limits.conf file and add:

```shell
your_username soft nofile 4096
your_username hard nofile 4096
```