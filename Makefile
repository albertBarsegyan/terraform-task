TF_DIR := terraform

.PHONY: fmt validate plan apply destroy kubeconfig pods nodes ingress grafana
fmt:
	terraform -chdir=$(TF_DIR) fmt -recursive
	npm --prefix app run format
lint:
	npm --prefix app run lint
validate:
	terraform -chdir=$(TF_DIR) init -backend=false
	terraform -chdir=$(TF_DIR) validate
plan:
	terraform -chdir=$(TF_DIR) plan
apply:
	terraform -chdir=$(TF_DIR) apply
destroy:
	terraform -chdir=$(TF_DIR) destroy
kubeconfig:
	aws eks update-kubeconfig --region $${AWS_REGION:-$$(terraform -chdir=$(TF_DIR) output -raw aws_region)} --name $$(terraform -chdir=$(TF_DIR) output -raw cluster_name)
pods:
	kubectl get pods -A
nodes:
	kubectl get nodes -o wide
ingress:
	kubectl get ingress -A
grafana:
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
