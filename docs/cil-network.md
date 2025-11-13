Types of Network Policy
Network Policies allow users to define what traffic is permitted in a Kubernetes cluster. Where traditional firewalls are configured to permit or deny traffic based on source or destination IP addresses and ports, Cilium uses Kubernetes identity information such as label selectors, namespace names, and even fully-qualified domain names for defining rules about what traffic is permitted and disallowed. This allows network policies to work in a dynamic environment like Kubernetes, where IP addresses are constantly being used and reused for different pods as those pods are created and destroyed.

When running Cilium on Kubernetes, you can define network policies using Kubernetes resources. Cilium agents will watch the Kubernetes API server for updates to network policies and will load the necessary eBPF programs and maps to ensure the desired network policy is implemented. Three network policy formats are available with Cilium enabled Kubernetes:

The standard Kubernetes NetworkPolicy resource which supports layer 3 and 4 policies.
The CiliumNetworkPolicy resource which supports Layers 3, 4, and 7 (application layer) policies.
The CiliumClusterwideNetworkPolicy resource for specifying policies that apply to an entire cluster rather than a specified namespace.
Cilium supports using all of these policy types at the same time. However, caution should be applied when using multiple policy types, as it can be confusing to understand the complete set of allowed traffic across multiple policy types. If close attention is not applied, this may lead to unintended policy behavior. As you’ll see in this section, the visualization tool at networkpolicy.io can help to understand the impact of different policy definitions.

This course will focus primarily on the CiliumNetworkPolicy resource, as it represents a superset of capabilities of the standard Kubernetes NetworkPolicy.

---

NetworkPolicy Resources
The NetworkPolicy resource is a standard Kubernetes resource that lets you control traffic flow at the IP address or port level (Open Systems Interconnection(OSI) model layer 3 or 4). The NetworkPolicy capabilities include:

L3/L4 Ingress and Egress policy using label matching;
L3 IP/CIDR Ingress and Egress policy using IP/CIDR for cluster external endpoints;
L4 TCP and ICMP port Ingress and Egress policy.

---

CiliumNetworkPolicy Resources
CiliumNetworkPolicy is an extension of the standard NetworkPolicy. CiliumNetworkPolicy extends the standard Kubernetes NetworkPolicy resource L3/L4 functionality with several additional capabilities:

L7 HTTP protocol policy rules, limiting Ingress and Egress to specific HTTP paths
Support for additional L7 protocols such as DNS, Kafka and gRPC
Service name-based Egress policy for internal cluster communications
L3/L4 Ingress and Egress policy using Entity matching for special entities
L3 Ingress and Egress policy using DNS FQDN matching.
You can find specific examples of CiliumNetworkPolicy YAML manifests for several common use-cases in the Cilium project documentation.

It can be hard to read the YAML definition of a network policy and predict what traffic it will permit and deny, and it's not trivial to craft policies to have precisely the effect you want. Fortunately, there is a visual policy editor at networkpolicy.io to make this much easier.

Introduction to the Networkpolicy.io Policy Editor
The NetworkPolicy.io policy editor provides a great way to explore and craft L3 and L4 network policy, by providing you with a graphical depiction of a cluster and letting you select the correct policy elements scoped for the desired type of network policy. The policy editor supports both standard Kubernetes NetworkPolicy and CiliumNetworkPolicy resources.

Let’s take a quick look at a screenshot from the policy editor.



A screenshot taking from the NetworkPolicy.ui policy editor interface. At the top there is an interactive service map that can be used to to generate network policy. On the bottom left the current network policy depicted in the service map is provided as a yaml manifest for one of the supported policy types.  On the bottom right is an area with tutorial information that can be used to help you learn how to write network policy for some common situations.

The NetworkPolicy.io Policy Editor



Across the top, there is an interactive service map visualization that you can use to create new policies. The green lines indicate traffic flow that is allowed and the red lines indicate traffic flow that is denied by the current policy definition. You can configure Ingress and Egress policies targeting either cluster internal or cluster external endpoints using the interactive service map UI.

At the lower left, there is a read-only YAML description of the network policy matching the service map depiction above. You can choose either to view the standard Kubernetes NetworkPolicy specification or the CiliumNetworkPolicy specification. From here you can also download the policy to apply it to your cluster with kubectl. You can also upload an existing policy definition in either format and the policy editor will update the visual service map representation to show how it works. Being able to visualize what a policy will do in the service map UI helps ensure the policy rules work as intended. You’ll have a chance to try the NetworkPolicy editor for yourself in the labs following this section.

At the lower right, the editor provides a tutorial interface populated with common situations to help you think through how to craft policy. You can also use the area to upload Hubble flows and generate network policies from what Hubble can observe. After we cover Hubble flows in the next chapter, you can come back to networkpolicy.io and upload some Hubble flows to the policy editor for additional practice.

Note: The policy editor (as of this writing) isn’t yet able to craft the L7 policy that CiliumNetworkPolicy supports. To take advantage of L7 policy, you can start with L3/L4 policy crafted by the policy editor, and then extend it to include L7 Ingress/Egress rules manually. We’ll discuss the L7 capabilities in more detail now.

---

L7 HTTP Policy
When any L7 HTTP policy is active for any endpoint running on a node, the Cilium agent on that node will start an embedded local-only HTTP proxy service and the eBPF programs will be instructed to forward packets on to that local HTTP proxy. The HTTP proxy is responsible for interpreting the L7 network policy rules and forwarding the packet further if appropriate. In addition, once the HTTP proxy is in place, you can gain L7 observability in Hubble flows, which we will get to in the next chapter.

When writing L7 HTTP policy, there are several fields that the HTTP proxy can use to match network traffic:

Path
An extended POSIX regex matched against the conventional path of a URL request. If omitted or empty, all paths are allowed.
Method
The method of a request, e.g., GET, POST, PUT, PATCH, DELETE. If omitted or empty, all methods are allowed.
Host
An extended POSIX regex matched against the host header of a request. If omitted or empty, all hosts are allowed.
Headers
A list of HTTP headers that must be present in the request. If omitted or empty, requests are allowed regardless of the headers present.
The following example uses several L7 HTTP protocol rules featuring regex path definitions to extend the L4 policy limiting all endpoints which carry the labels app=myService to only be able to receive packets on port 80 using TCP. While communicating on this port, the only HTTP API endpoints allowed will be:

GET /v1/path1
This matches the exact path"/v1/path1".
PUT /v2/path2.*
This matches all paths starting with "/v2/path2".
POST .*/path3
This matches all paths ending in "/path3" with the additional constraint that the HTTP header X-My-Header must be set to true.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "l7-rule"
spec:
  endpointSelector:
    matchLabels:
      app: myService
  ingress:
  - toPorts:
    - ports:
      - port: '80'
        protocol: TCP
      rules:
        http:
        - method: GET
          path: "/v1/path1"
        - method: PUT
          path: "/v2/path2.*"
        - method: POST
          path: ".*/path3"
          headers:
          - 'X-My-Header: true'
```

The rules block holds the L7 policy logic that extends the L4 ingress policy. You can start with an L4 policy and provide granular HTTP API support by just adding the appropriate rules block as an attribute in the toPorts list.