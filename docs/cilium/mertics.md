# Cilium Operator Metrics
The Cilium operator Prometheus metrics can be enabled using a Helm chart option and are used primarily for providing observability to diagnose and alert degraded operator performance. Enabling operator metrics is usually done as part of the Cilium install process. When enabled using the supported install methods, the operator pods are annotated to aid in Prometheus endpoint discovery.

Operator metrics include information concerning the state of the Cilium operator. These metrics are prefixed with "cilium_operator_".

## The Cilium agent metrics can be grouped into several categories. Some important metric categories include:

*Cluster Health
  Statistics on unreachable nodes and agent health endpoints
*Node Connectivity
  Statistics covering latency to nodes across the network
*Cluster Mesh
  Statistics concerning peer clusters
*Datapath
  Statistics related to garbage collection of connection tracking
*IPSec
  Statistics associated with IPSec errors
*eBPF
  Statistics on eBPF map operations and memory use
*Drops/Forwards (L3/L4)
  Statistics on packet drops/forwards.
*Policy
  Statistics on active policy
*Policy L7 (HTTP/Kafka)
 Statistics for L7 policy redirects to embedded HTTP proxy
*Identity
 Statistics concerning Identity to IP address mapping
*Kubernetes
 Statistics concerning received Kubernetes events
*IPAM
 IP address allocation statistics


## Hubble Metrics
Hubble metrics are based on network flow information and as such are most relevant to understanding traffic flows, rather than the operational performance of Cilium itself.

Hubble metric categories include:

*DNS
  Statistics about DNS requests made
*Drop
  Statistics about packet drops
*Flow
  Statistics concerning total flows processed
*HTTP
  Statistics concerning HTTP requests
*TCP
  Statistics concerning TCP packets
*ICMP
  Statistics concerning ICMP packets
*Port Distribution
  Statistics concerning destination ports


https://github.com/cilium/cilium/tree/main/examples/kubernetes/addons/prometheus


## Chart Options

 Enabling Cilium Operator Metrics
There are two Helm chart options that influence Cilium operator metrics collection:
`operator.prometheus.port` - Set the operator metrics tcp port (default is 9962)
`operator.prometheus.enabled` - true/false (default is false)

Enabling Cilium Agent Metrics
There are four Helm chart options that influence Cilium agent metrics collection:

`prometheus.proxy.port` - Set the proxy metrics tcp port (default is 9964)
`prometheus.port` - Set the agent metrics tcp port (default is 9962)
`prometheus.metrics` - Space delimited string indicated with Cilium agent metrics to enable/disable
Ex: "-cilium_node_connectivity_status +cilium_bpf_map_pressure"

`prometheus.enabled` - true/false (default is false)
Enabling Hubble Metrics
There are four Helm chart options that influence Cilium agent metrics collection:

`hubble.metrics.enableOpenMetrics` - true/false (default is false)
`hubble.metrics.port` - Set the Hubble metrics tcp port (default is 9965)
`hubble.metrics.enabled` - Comma-delimited list of metrics to enable, with each metric having its own list of options to enable. At least one metric must be provided to enable the Hubble metrics server
Ex: "{first-metric:metric-option1;metric-option2, second-metric, third-metric}"
`prometheus.enabled` - true/false (default is false)
In the next section, we’ll re-install Cilium using Helm and enable Hubble metrics that we can visualize in our own Grafana dashboards.


## Demo


Now let’s reinstall the Death Star API application so we can have some metrics to look at:

```shell
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/minikube/http-sw-app.yaml
```
And let’s apply a simple CiliumNetworkPolicy rule to restrict access to the service to Imperial units:

`https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/minikube/sw_l3_l4_l7_policy.yaml
`
If you are reusing a cluster from the previous chapters, you may have other CiliumNetworkPolicy rules in place; that’s fine. We’re just making sure you have at least a common rule in place so we can create DROPPED flow verdicts we can catch in the Hubble metrics.

### Enable Cilium Metrics Collection
Now let's enable the Cilium operator and agent metrics using Helm:

```shell
helm upgrade cilium cilium/cilium --namespace=kube-system --reuse-values --set prometheus.enabled=true --set operator.prometheus.enabled=true
```
The cilium agent pods should now have a prometheus.io.port annotation:

```shell
kubectl get -n kube-system pod/cilium-59bf7 -o json | jq .metadata.annotations
{
  "prometheus.io/port": "9962",
  "prometheus.io/scrape": "true"
}
```

We have chosen the cilium-59bf7 pod because it is on the same node as the deathstar-54bb8475cc-fz92t pod acting as an endpoint for the Death Star service in our cluster. If you choose a Cilium pod running on the same node as either your TIE fighter pod or one of your Death Star service endpoint pods, if examining the Cilium and Hubble metrics, it will contain information about network flows captured on that node from either TIE fighter to the Death Star endpoint. The node running the TIE fighter pod will have egress flow metrics. The pod containing the Death Star endpoint pod will ingress flow metrics. A node running both pods (like in the example from our cluster) will have both ingress and egress flow metrics.

Let’s use the curl command from the tiefighter pod to look at the Cilium agent metrics endpoint. First, let's get the IP address for the Cilium agent pod:

```shell
kubectl get -n kube-system pod/cilium-59bf7 -o json | jq .status.podIP
"10.89.0.8"

kubectl exec -ti pod/tiefighter -- curl http:‌//10.89.0.8:9962/metrics
# HELP cilium_agent_api_process_time_seconds Duration of processed API calls labeled by path, method and return code.
# TYPE cilium_agent_api_process_time_seconds histogram
cilium_agent_api_process_time_seconds_bucket{method="DELETE",path="/v1/endpoint",return_code="200",le="0.005"} 3
cilium_agent_api_process_time_seconds_bucket{method="DELETE",path="/v1/endpoint",return_code="200",le="0.01"} 3
…

```

Note: You'll need to replace cilium-59b57 with the correct pod name for your cluster and then use the appropriate pod IP address in the curl command.

Great! The Prometheus metrics for the Cilium agent are live! You can do the same procedure and examine the Cilium operator metrics using the operator pod’s IP address and Prometheus port annotation.

Let’s do a few X-wing landing requests:

```shell
kubectl exec xwing -- curl -s --connect-timeout 2 -XPOST deathstar.default.svc.cluster.local/v1/request-landing
command terminated with exit code 28
```

and then check the Cilium agent’s dropped packet metrics.

```shell
kubectl exec -ti pod/xwing -- curl http:‌//10.89.0.8:9962/metrics| grep drop_count_total
# HELP cilium_drop_count_total Total dropped packets, tagged by drop reason and ingress/egress direction
# TYPE cilium_drop_count_total counter
cilium_drop_count_total{direction="INGRESS",reason="Policy denied"} 5
```

Because this particular Cilium agent is on the same node as one of the Death Star backend pods, the Ingress policy denied packet drops will increment every time the curl from the xwing pod attempts a request to the Death Star pod on this node. Let’s dig deeper into that by setting up Hubble metrics.



### Enable Hubble Metrics Collection
Let’s use Helm again to upgrade the Cilium install and enable some Hubble metrics of interest.

```shell
helm upgrade cilium cilium/cilium --version 1.16.3 --namespace kube-system --reuse-values --set hubble.enabled=true --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,httpV2}"
```
Restart the Cilium daemonset to ensure the configuration changes are active:

```shell
kubectl rollout restart daemonset/cilium -n kube-system
```

There should now be a new headless service called hubble-metrics:

```shell

kubectl -n kube-system get services
NAME           TYPE       CLUSTER-IP EXTERNAL-IP PORT(S)  AGE
cilium-agent   ClusterIP   None      <none>      9964/TCP 177m
hubble-metrics ClusterIP   None      <none>      9965/TCP 113m

kubectl -n kube-system describe service/hubble-metrics
Name:        hubble-metrics
Namespace:   kube-system
Labels:      app.kubernetes.io/managed-by=Helm
             app.kubernetes.io/name=hubble
             app.kubernetes.io/part-of=cilium
             k8s-app=hubble
Annotations: meta.helm.sh/release-name: cilium
             meta.helm.sh/release-namespace: kube-system
             prometheus.io/port: 9965
             prometheus.io/scrape: true
Selector:    k8s-app=cilium
Type:        ClusterIP
IP Family Policy: SingleStack
IP Families: IPv4
IP:          None
IPs:         None
Port:        hubble-metrics 9965/TCP
TargetPort:  hubble-metrics/TCP
Endpoints:   10.89.0.6:9965,10.89.0.7:9965,10.89.0.8:9965
Session Affinity: None
Events:      <none>
```

We can curl from the tiefighter pod to the metrics port of one of the listed backends and see the Hubble metrics we’ve enabled.

```shell
kubectl exec -ti pod/tiefighter -- curl http:‌//10.89.0.8:9965/metrics | grep hubble_drop
# HELP hubble_drop_total Number of drops
# TYPE hubble_drop_total counter
hubble_drop_total{protocol="ICMPv6",reason="UNSUPPORTED_L3_PROTOCOL"} 106
hubble_drop_total{protocol="TCP",reason="POLICY_DENIED"} 14
hubble_drop_total{protocol="TCP",reason="STALE_OR_UNROUTABLE_IP"} 190

kubectl exec -ti pod/tiefighter -- curl http:‌//10.89.0.8:9965/metrics | grep hubble_tcp
# HELP hubble_tcp_flags_total TCP flag occurrences
# TYPE hubble_tcp_flags_total counter
hubble_tcp_flags_total{family="IPv4",flag="FIN"} 2846
hubble_tcp_flags_total{family="IPv4",flag="RST"} 1223
hubble_tcp_flags_total{family="IPv4",flag="SYN"} 2245
hubble_tcp_flags_total{family="IPv4",flag="SYN-ACK"} 2137

If we make more X-wing landing requests:

kubectl exec xwing -- curl -s --connect-timeout 2 -XPOST deathstar.default.svc.cluster.local/v1/request-landing
command terminated with exit code 28

we should now see the policy denied drop count increase:

kubectl exec -ti pod/tiefighter -- curl http:‌//10.89.0.8:9965/metrics | grep hubble_drop
# HELP hubble_drop_total Number of drops
# TYPE hubble_drop_total counter
...
hubble_drop_total{protocol="TCP",reason="POLICY_DENIED"} 16
```

### Dashboards For The Win
So far, we have demonstrated that the Cilium and Hubble metric endpoints are reachable. For those of you taking this course with some Prometheus and Grafana experience, you should now have enough information to adjust the configurations of those tools to start incorporating Cilium and Hubble metrics into your dashboards and alerts.

For everyone who isn’t familiar with those tools yet, don’t fret. The Cilium project provides an example of a Prometheus and Grafana dashboard service that you can install into your lab cluster right now so you can experience the joy of seeing Hubble metrics appearing in a dashboard.

The following command will set up a cilium-monitoring namespace and deploy an example Prometheus and Grafana configured to ingest the Cilium and Hubble metrics.

```shell
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/refs/heads/main/examples/kubernetes/addons/prometheus/monitoring-example.yaml
```

Set up a local port forward of the Grafana service:

```shell
kubectl -n cilium-monitoring port-forward service/grafana --address 0.0.0.0 --address :: 3000:3000


Open up a browser to http:‌//localhost:3000 and you should be able to navigate to one of the example dashboards like the General/Hubble dashboard: