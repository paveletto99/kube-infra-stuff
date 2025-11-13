# Cilium Components

Close Cilium Operator
The Cilium operator is responsible for managing duties in the cluster which should logically be handled once for the entire cluster, rather than once for each node in the cluster. The Cilium operator is not in the critical path for any forwarding or network policy decision. A cluster will generally continue to function if the operator is temporarily unavailable.

Close Cilium Agent
The Cilium agent runs as a daemonset so that there is a Cilium agent pod running on every node in your Kubernetes cluster. The agent does the bulk of the work associated with Cilium:

Interacts with Kubernetes API server to synchronize cluster state.
Interacts with the Linux kernel - loading eBPF programs and updating eBPF maps.
Interacts with the Cilium CNI plugin executable, via a filesystem socket, to get notified of newly scheduled workloads.
Creates on-demand DNS and Envoy proxies as needed based on requested network policy.
Creates Hubble gRPC services when Hubble is enabled.
Close Cilium Client
Each pod in the Cilium agent daemonset comes with a Cilium client executable that can be used to inspect the state of Cilium agent and eBPF maps resources installed on that node. The client communicates with the Cilium agent’s REST API from inside the daemonset pod.

Note: This is not the same as the Cilium CLI tool executable that you installed on your workstation. The Cilium client executable is included in each Cilium agent pod, and can be used as a diagnostic tool to help troubleshoot Cilium agent operation if needed. You’ll seldom interact with the Cilium client as part of normal operation, but we’ll use it in some of the labs to help us see into the internals of the Cilium network state as we work with some of the Cilium capabilities.

Close Cilium CNI Plugin
The Cilium agent daemonset also installs the Cilium CNI plugin executable into the Kubernetes host filesystem and reconfigures the node’s CNI to make use of the plugin. The CNI plugin executable is separate from the Cilium agent, and is installed as part of the agent daemonset initialization. When required, the Cilium CNI plugin will communicate with the running Cilium agent using a host filesystem socket.

Close Hubble Server
The Hubble server runs on each node and retrieves the eBPF-based visibility from Cilium. It is embedded into the Cilium agent to achieve high performance and low overhead. It offers a gRPC service to retrieve flows and Prometheus metrics.

Close Hubble Relay
When Hubble is enabled as part of a Cilium-managed cluster, the Cilium agents running on each node are restarted to enable the Hubble gRPC service to provide node-local observability. For cluster-wide observability, a Hubble Relay deployment is added to the cluster along with two additional services; the Hubble Observer service and the Hubble Peer service.

The Hubble Relay deployment provides cluster-wide observability by acting as an intermediary between the cluster-wide Hubble Observer service and the Hubble gRPC services that each Cilium agent provides. The Hubble Peer service makes it possible for Hubble Relay to detect when new Hubble-enabled Cilium agents become active in the cluster. As a user, you will typically be interacting with the Hubble Observer service, using either the Hubble CLI tool or the Hubble UI, to gain insights into the network flows across your cluster that Hubble provides. The cluster you installed in this chapter’s lab should have Hubble enabled. We’ll get hands-on with Hubble in more detail in Chapter 5.

Close Hubble CLI & GUI
The Hubble CLI (hubble) is a command line tool able to connect to either the gRPC API of hubble-relay or the local server to retrieve flow events.

The graphical user interface (hubble-ui) utilizes relay-based visibility to provide a graphical service dependency and connectivity map.

Close Cluster Mesh API Server
The Cluster Mesh API server is an optional deployment that is only installed if you enable the Cilium Cluster Mesh feature. Cilium Cluster Mesh allows Kubernetes services to be shared amongst multiple clusters.

Cilium Cluster Mesh deploys an etcd key-value store in each cluster, to hold information about Cilium identities. It also exposes a proxy service for each of these etcd stores. Cilium agents running in any member of the same Cluster Mesh can use this service to read information about Cilium identity state globally across the mesh. This makes it possible to create and access global services that span the Cluster Mesh. Once the Cilium Cluster Mesh API service is available, Cilium agents running in any Kubernetes cluster that is a member of the Cluster Mesh are then able to securely read from each cluster’s etcd proxy thus gaining knowledge of Cilium identity state globally across the mesh. This makes it possible to create global services that span the cluster mesh. We’ll cover the capabilities of the Cilium Cluster Mesh in more detail in a later chapter.