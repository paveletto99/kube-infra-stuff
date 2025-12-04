# 🔮
KIND_CLUSTER_NAME=cluster-dev01
KIND_CREATE_CLUSTER_SCRIPT=$(PWD)/kubernetes/kind/kind-create-cluster-with-registry
KIND_HOST_MOUNT_PATH=$(HOME)/opt/kind-${KIND_CLUSTER_NAME}-pv/
# KIND_KUBECONFIG_DIR=${WINHOME}/.kube
KIND_KUBECONFIG_DIR=${HOME}/.kube
KIND_KUBECONFIG_FILE=${KIND_KUBECONFIG_DIR}/kind-kubernetes-clusters-${KIND_CLUSTER_NAME}.kubeconfig
KIND_KUBERNETES_ADMIN_USER=admin-user
KIND_NETWORK_NAME=kind
KIND_NODE_IMAGE=kindest/node:v1.34.0@sha256:7416a61b42b1662ca6ca89f02028ac133a309a2a30ba309614e8ec94d976dc5a
KIND_REGISTRY_NAME=kind-registry
KIND_REGISTRY_PORT=5000
WINHOME=$(shell ./tools/scripts/get_win_home.sh)
# extract the local ip address to add host on $(CRI_ENGINE) enviroment
LOCAL_HOST_ADDR= $(shell ip route show | grep -Pom 1 '[0-9.]{7,15}')
# LOCAL_HOST_ADDR= $(shell ip route show | awk '{print $$9}' | xargs)
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt


CRI_ENGINE=docker


# export KIND_EXPERIMENTAL_PROVIDER=podman
export KUBECONFIG=${KIND_KUBECONFIG_FILE}

.SILENT: kind-create-cluster kind-delete-cluster get-cluster-token deploy-k8s undeploy-k8s kube-linter ks
.ONESHELL: kind-create-cluster kind-delete-cluster deploy-k8s undeploy-k8s ks

kind-create-cluster:
	(
		( kind get clusters | grep -q ${KIND_CLUSTER_NAME} ) && ( echo "Cluster ${KIND_CLUSTER_NAME} already exists" && exit 0; )
	) || (

		echo "Creating Kubernetes cluster.... 🏗️"

		if [ -f "${KIND_CREATE_CLUSTER_SCRIPT}" ]; then
			$(KIND_CREATE_CLUSTER_SCRIPT) ${KIND_NETWORK_NAME} ${KIND_CLUSTER_NAME} ${KIND_KUBECONFIG_DIR} ${KIND_KUBECONFIG_FILE} ${KIND_NODE_IMAGE} ${KIND_REGISTRY_NAME} ${KIND_REGISTRY_PORT} ${KIND_KUBERNETES_ADMIN_USER} ${KIND_HOST_MOUNT_PATH} $(CRI_ENGINE)
		else
			( echo "${KIND_CREATE_CLUSTER_SCRIPT} not Found!" && exit 1 ; )
		fi
	)
.PHONY: kind-create-cluster

kind-create-cilium-cluster:
	kind create cluster --name cilium-playground \
		--config=./kubernetes/kind/kind-cilium.yaml \
		--kubeconfig  ${KIND_KUBECONFIG_DIR}/kind-cilium-play.kubeconfig
	export KUBECONFIG=${KIND_KUBECONFIG_DIR}/kind-cilium-play.kubeconfig
	cilium install
	cilium status --wait
	cilium hubble enable --ui
	cilium connectivity test --request-timeout 30s --connect-timeout 10s
.PHONY: create-cilium-cluster

kind-config-cluster:
	docker exec -t $(name) bash -c "echo 'fs.inotify.max_user_watches=1048576' >> /etc/sysctl.conf"
	docker exec -t $(name) bash -c "echo 'fs.inotify.max_user_instances=512' >> /etc/sysctl.conf"
	docker exec -i $(name) bash -c "sysctl -p /etc/sysctl.conf"
.PHONY: kind-config-cluster


get-cluster-token:
# kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
	kubectl -n kubernetes-dashboard describe secret $$(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $$1}') | grep token: | awk -F 'token:' '{print $$2}' | sed 's/ //g'
.PHONY: get-cluster-token

kind-delete-cluster:
	$(CRI_ENGINE) network disconnect "${KIND_NETWORK_NAME}" "${KIND_REGISTRY_NAME}"
	kind delete cluster --name ${KIND_CLUSTER_NAME}
.PHONY: kind-delete-cluster

deploy-observability-k8s:
	kubectl create ns observability
	kubectl apply -f kubernetes/13-open-telemetry-collector.yaml
	kubectl apply -f kubernetes/11-prometheus.yaml
	kubectl apply -f kubernetes/12-grafana.yaml
	kubectl apply -f kubernetes/14-jaeger-svc.yaml
	kubectl apply -f kubernetes/clusters/tms-dev/99-ingress.yaml
.PHONY: deploy-observability-k8s

undeploy-observability-k8s:
	kubectl delete -f kubernetes/99-ingress.yaml
	kubectl delete -f kubernetes/13-open-telemetry-collector.yaml
	kubectl delete -f kubernetes/11-prometheus.yaml
	kubectl delete -f kubernetes/12-grafana.yaml
	kubectl delete -f kubernetes/14-jaeger-svc.yaml
	kubectl delete ns observability
.PHONY: undeploy-observability-k8s

# CI 🚀
run-pipe:
	go run ci/main.go
.PHONY: run-pipe

# Scylla 👹
run-scylla:
	cd docker
	docker-compose -f compose-scylla.yaml up -d
	docker exec scylla-node1 cqlsh -f /mutant-data.txt
.PHONY: run-scylla

destroy-scylla:
	cd docker
	docker-compose kill
	docker-compose -f compose-scylla.yaml rm -f
.PHONY: destroy-scylla


# Terraform

tf-validate:
	cd ./infra/ci
	dagger call validate --source="~/myspace/kube-rs-ctrl/terraform"
.PHONY: tf-validate

tf-plan:
	cd ./infra/ci
	dagger call plan --source="~/myspace/kube-rs-ctrl/terraform"
.PHONY: tf-plan

tf-state-enc:
	sops --encrypt terraform/terraform.tfstate > terraform/terraform.tfstate.enc
	if [ -f terraform/terraform.tfstate ]; then\
		rm terraform/terraform.tfstate;\
	fi
	echo "🔒 Terraform state encrypted."
.PHONY: tf-state-enc

tf-state-dec:
	SOPS_AGE_KEY_FILE=${SOPS_AGE_KEY_FILE} sops --decrypt terraform/terraform.tfstate.enc > terraform/terraform.tfstate
	echo "🔓 Terraform state decrypted."
.PHONY: tf-state-dec

gen-age-key:
	if [ ! -d ~/.config/sops/age ]; then\
		mkdir -p ~/.config/sops/age;\
	fi
	if [ -f ${SOPS_AGE_KEY_FILE} ]; then\
		rm ${SOPS_AGE_KEY_FILE};\
	fi
	age-keygen -o ${SOPS_AGE_KEY_FILE}
# ${SOPS_AGE_KEY_FILE} | grep public
