# Cilium Network Policy Exercise

```shell
kubectl create -f https:‌//raw.githubusercontent.com/cilium/cilium/HEAD/examples/minikube/http-sw-app.yaml

# 

kubectl get pods,CiliumEndpoints -o wide

```

Cilium has created endpoints corresponding to both Death Star backend pods, as well as the X-wing and TIE fighter pods.

Note: Both deathstar-* endpoints share the same IDENTITY ID. As we discussed in the previous chapter, they share the same Cilium Identity because they both have the same set of security-relevant labels. Cilium agents will use the Identity ID for endpoints matching relevant network policy to facilitate efficient key-value lookups in the operation of eBPF programs operating in the network datapath.

Back to the task at hand! There’s no network policy in place yet, so there should be nothing stopping either X-wing or TIE fighters from accessing the cluster-internal Death Star service by its fully qualified domain name (FQDN) and then having either kube-proxy or Cilium forward the HTTP based landing request to one of the Death Star backend pods. Yes! You read that correctly, kube-proxy or Cilium, we'll cover the benefits of replacing kube-proxy with Cilium in a later chapter.

Time to make some landing requests for both the TIEs and the X-wings:

```shell
kubectl exec xwing -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

kubectl exec tiefighter -- curl -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed

```

The Death Star service is up and running, time to implement network policy and limit access to it from just the pods we want.

---

## L4 network policy


Empire Ingress Allow Policy
The simplest way to ensure the X-wing pods don’t have access to the Death Star service endpoints in this cluster is to write a label-based L3 policy that takes advantage of the different labels used in the pods. An L3 policy would restrict access to all network ports at the endpoint. If you want to limit access to a specific port number, you can write a label-based L4 policy.

If you inspect the xwing pod you will see it is labeled with org=alliance and the tiefighter pod is labeled with org=empire:

```shell
kubectl describe pod/xwing
Name:            xwing
Namespace:       default
Priority:        0
Service Account: default
Node:            kind-worker2/172.18.0.2
Start Time:      Wed, 06 Nov 2024 11:50:34 +0000
Labels:          app.kubernetes.io/name=xwing
                 class=xwing
                 org=alliance
…

kubectl describe pod/tiefighter
Name:            tiefighter
Namespace:       default
Priority:        0
Service Account: default
Node:            kind-worker/172.18.0.3
Start Time:      Wed, 06 Nov 2024 11:50:34 +0000
Labels:          app.kubernetes.io/name=tiefighter
                 class=tiefighter
                 org=empire

…

```


An L4 network policy referencing TCP port 80 that only allows pods labeled with org=empire will prevent the xwing pod from accessing the Death Star service endpoints. We can craft this policy using the networkpolicy.io policy editor.

First, edit the central service-map element to configure the policy name and endpointSelector, we’ll want to make sure this policy only applies to the pods acting as Death Star service endpoints by adding the org=empire and class=deathstar labels.


```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-empire-in-namespace
spec:
  endpointSelector:
    matchLabels:
      org: empire
      class: deathstar
  ingress:
    - fromEndpoints:
        - matchLabels:
            org: empire
      toPorts:
        - ports:
            - port: "80"

```

Note this L4 policy specifically restricts ingress access to the deathstar-* pods acting as service endpoints and not the Death Star service itself.

If you want to restrict a pod’s egress access to a limited number of services, you could create an egress policy for the client pod that references allowed services by name in the toServices attribute of the Egress policy. In our case, that would mean writing Egress for both xwing and tiefighter pods with differing toServices information. That’s possible, but it’s much easier to meet our goal with a single Ingress policy this time that just allows Imperial units access to the Death Star API, and deny everything else access.

Whether you should write Ingress or Egress policy comes down to a matter of intent. Are you trying to control what a pod is allowed to send information to? If so, Egress is probably the policy you want to write. If you are trying to control which pods can initiate communication with a particular service or endpoint, then Ingress policy is most likely the simplest way to address that intent.

You can download the L4 policy from the policy editor UI into a file named allow-empire-in-namespace.yaml and apply it to your cluster:

```shell
kubectl apply -f allow-empire-in-namespace.yaml
ciliumnetworkpolicy.cilium.io/allow-empire-in-namespace configured
```

Now with the policy in place, the X-Wing should no longer be able to access the landing request API:

```shell
kubectl exec xwing -- curl --connect-timeout 10 -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
command terminated with exit code 28
```

The curl command issued from the xwing pod times out with an error.

But the same command issued for the tiefighter pod will still succeed:

```shell
kubectl exec tiefighter -- curl --connect-timeout 10 -s -XPOST deathstar.default.svc.cluster.local/v1/request-landing
Ship landed
```

Success! The X-wing pods no longer have access to the Death Star API, but all other pods labeled as org=empire still have access to the full API, including the troublesome exhaust port:

```shell
kubectl exec tiefighter -- curl -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
Panic: deathstar exploded
```

Yikes! But we can fix that with L7 HTTP policy that limits access even further, so the exhaust-port API endpoint is only available to Imperial maintenance droids and not hotshot rookie pilots who can’t tell a landing bay from an exhaust port. We can address the design flaws in the API’s exhaust-port endpoint in our next development sprint (why does the API even need an exhaust port?), but for now let’s use the CiliumNetworkPolicy Custom Resource Definition to restrict access so it doesn’t happen again.

---


## Add L7 HTTP Path Specific Allow Policy

Let’s extend the empire access policy to include the rules for landing path and exhaust port paths explicitly.

These rules will now match on both org and class labels.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-empire-in-namespace
spec:
  endpointSelector:
    matchLabels:
      org: empire
      class: deathstar
  ingress:
  - fromEndpoints:
    - matchLabels:
        org: empire
        class: tiefighter
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "POST"
          path: "/v1/request-landing"
  - fromEndpoints:
    - matchLabels:
        org: empire
        class: maintenance-droid
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "PUT"
          path: "/v1/exhaust-port"
```
Save this policy update to the file allow-empire-in-namespace.yaml and apply to your cluster:

```shell
kubectl apply -f allow-empire-in-namespace.yaml
ciliumnetworkpolicy.cilium.io/allow-empire-in-namespace configured
```


Now instead of being able to reach the exhaust-port, the TIE fighters will be given an HTTP 403 forbidden access message, courtesy of the embedded HTTP proxy the Cilium agent is running on the nodes where Death Star back-end pods are running.

```shell
kubectl exec tiefighter -- curl -v -s -XPUT deathstar.default.svc.cluster.local/v1/exhaust-port
* Trying 10.96.39.100...
* TCP_NODELAY set
* Connected to deathstar.default.svc.cluster.local (10.96.39.100) port 80 (#0)
> PUT /v1/exhaust-port HTTP/1.1
> Host: deathstar.default.svc.cluster.local
> User-Agent: curl/7.52.1
> Accept: */*
>
< HTTP/1.1 403 Forbidden
< content-length: 15
< content-type: text/plain
< date: Wed, 06 Nov 2024 15:12:58 GMT
< server: envoy
<
{ [15 bytes data]
* Curl_http_done: called premature == 0
* Connection #0 to host deathstar.default.svc.cluster.local left intact
Access denied
```


The X-wing trying to access the Death Star API is still denied access via the L4 policy, which has the packets dropped resulting in a connection timeout instead of an HTTP forbidden status message.

We’ve successfully limited access to the Death Star API so TIE fighters can make landing requests, without giving them access to the exhaust port. And we’ve kept any X-wings in the cluster from accessing the Death Star API at all. Lord Vader will be pleased.

Note: The difference in behavior in how the L3/4 policy and L7 policy handle dropped packets is expected, because of the different implementations being used. For L3/L4 policy the eBPF programs running in the Linux network datapath are used to drop the packet, essentially eaten by a black hole in the network. The L7 policy is implementing the embedded HTTP proxy and making decisions as if it were an HTTP server, denying requests and providing an HTTP status response back to the client with a reason as to why it was denied. Regardless of the implementation being used, you will be able to track that a packet was dropped at the Death Star endpoint ingress using Hubble to examine network flows. We’ll cover that in the next chapter.