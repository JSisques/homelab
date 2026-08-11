SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

TF_DIR       := terraform/proxmox
ANSIBLE_DIR  := ansible
INVENTORY    := inventory/hosts.yml

SERVICES := it-tools n8n obsidian monitoring homepage uptime-kuma cloudflared adguard-home traefik wireguard pbs promtail k3s-server

ANSIBLE_EXTRA_VARS := \
	-e "n8n_postgres_password=$${N8N_POSTGRES_PASSWORD}" \
	-e "cloudflared_credentials_json=$${CLOUDFLARED_CREDS_JSON}" \
	-e "monitoring_alertmanager_telegram_bot_token=$${TELEGRAM_BOT_TOKEN}" \
	-e "monitoring_alertmanager_telegram_chat_id=$${TELEGRAM_CHAT_ID}"

.PHONY: help init fmt validate plan apply destroy \
	generate inventory terraform-vars \
	deploy ping status services

# NOTE: deploy-% (below) is intentionally NOT listed in .PHONY. Doing so
# would make GNU Make treat e.g. "deploy-n8n" as an explicit target with no
# recipe, which shadows the pattern rule instead of using it.

help: ## Show this help
	@echo "Usage: make <target>"
	@echo ""
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

services: ## List services that can be deployed individually (make deploy-<service>)
	@for s in $(SERVICES); do echo "$$s"; done

## --- Configuration generation (config/ -> everything else) --------------

generate: ## Regenerate Homepage, Prometheus, blackbox, Traefik, Terraform vars, and Ansible inventory from config/
	./scripts/generation/generate-homepage.sh
	./scripts/generation/generate-prometheus.sh
	./scripts/generation/generate-blackbox.sh
	./scripts/generation/generate-traefik.sh
	./scripts/generation/generate-terraform-vars.sh
	./scripts/generation/generate-inventory.sh

terraform-vars: ## Regenerate only terraform/proxmox/hosts.auto.tfvars.json
	./scripts/generation/generate-terraform-vars.sh

inventory: ## Regenerate only the Ansible inventory
	./scripts/generation/generate-inventory.sh

## --- Terraform (infrastructure) ------------------------------------------

init: terraform-vars ## Initialize Terraform
	cd $(TF_DIR) && terraform init

fmt: ## Format Terraform files
	cd $(TF_DIR) && terraform fmt -recursive

plan: terraform-vars ## Show what Terraform would change
	cd $(TF_DIR) && terraform plan

apply: terraform-vars ## Apply Terraform (provisions/updates all LXCs and VMs)
	cd $(TF_DIR) && terraform apply

destroy: ## Destroy all Terraform-managed infrastructure (DANGEROUS)
	cd $(TF_DIR) && terraform destroy

## --- Ansible (configuration + application deployment) --------------------

ping: inventory ## Check connectivity to every host in the inventory
	cd $(ANSIBLE_DIR) && ansible all -i $(INVENTORY) -m ping

deploy: apply inventory ## Deploy EVERYTHING: Terraform apply + every Ansible role
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/site.yaml $(ANSIBLE_EXTRA_VARS)

deploy-%: inventory ## Deploy a single service only, e.g. `make deploy-n8n` (see `make services`)
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/$*.yaml $(ANSIBLE_EXTRA_VARS)

## --- Validation -----------------------------------------------------------

validate: ## Run all local validation (Terraform, Ansible, YAML, shell, Compose)
	./scripts/validation/validate.sh

status: ## Show current Terraform-managed infrastructure
	cd $(TF_DIR) && terraform show
