SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

TF_DIR       := terraform/proxmox
ANSIBLE_DIR  := ansible
INVENTORY    := inventory/hosts.yml

SERVICES := it-tools n8n cookidoo-mcp obsidian jellyfin downloads monitoring homepage uptime-kuma cloudflared adguard-home-1 adguard-home-2 adguard-home-sync traefik wireguard pbs promtail k3s-server rustfs

ANSIBLE_EXTRA_VARS := \
	-e "n8n_postgres_password=$${N8N_POSTGRES_PASSWORD}" \
	-e "cookidoo_mcp_email=$${COOKIDOO_MCP_EMAIL}" \
	-e "cookidoo_mcp_password=$${COOKIDOO_MCP_PASSWORD}" \
	-e "cloudflared_credentials_json=$${CLOUDFLARED_CREDS_JSON}" \
	-e "monitoring_alertmanager_telegram_bot_token=$${TELEGRAM_BOT_TOKEN}" \
	-e "monitoring_alertmanager_telegram_chat_id=$${TELEGRAM_CHAT_ID}" \
	-e "downloads_vpn_service_provider=$${DOWNLOADS_VPN_SERVICE_PROVIDER}" \
	-e "downloads_vpn_wireguard_private_key=$${DOWNLOADS_VPN_WIREGUARD_PRIVATE_KEY}" \
	-e "downloads_vpn_wireguard_addresses=$${DOWNLOADS_VPN_WIREGUARD_ADDRESSES}" \
	-e "rustfs_access_key=$${RUSTFS_ACCESS_KEY}" \
	-e "rustfs_secret_key=$${RUSTFS_SECRET_KEY}" \
	-e "adguard_sync_origin_username=$${ADGUARD_SYNC_ORIGIN_USERNAME}" \
	-e "adguard_sync_origin_password=$${ADGUARD_SYNC_ORIGIN_PASSWORD}" \
	-e "adguard_sync_replica_username=$${ADGUARD_SYNC_REPLICA_USERNAME}" \
	-e "adguard_sync_replica_password=$${ADGUARD_SYNC_REPLICA_PASSWORD}"

# Loads a root .env (gitignored, see .env.example) into the shell environment
# for the recipe that follows, if one exists — so ANSIBLE_EXTRA_VARS above
# picks up real values instead of empty strings without exporting them by
# hand every session. Silently a no-op when there's no .env.
LOAD_ENV := if [ -f .env ]; then set -a && . ./.env && set +a; fi;

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
	$(LOAD_ENV) cd $(TF_DIR) && terraform init

fmt: ## Format Terraform files
	cd $(TF_DIR) && terraform fmt -recursive

plan: terraform-vars ## Show what Terraform would change
	$(LOAD_ENV) cd $(TF_DIR) && terraform plan

apply: terraform-vars ## Apply Terraform (provisions/updates all LXCs and VMs)
	$(LOAD_ENV) cd $(TF_DIR) && terraform apply

apply-%: terraform-vars ## Apply Terraform for a single LXC/VM only, e.g. `make apply-adguard-home-1` (see `make services`)
	@if jq -e --arg h "$*" '.lxc_network[$$h]' $(TF_DIR)/hosts.auto.tfvars.json >/dev/null; then \
		addr='proxmox_virtual_environment_container.lxc["$*"]'; \
	elif jq -e --arg h "$*" '.vm_nodes[$$h]' $(TF_DIR)/hosts.auto.tfvars.json >/dev/null; then \
		addr='proxmox_virtual_environment_vm.vm["$*"]'; \
	else \
		echo "Error: '$*' is not a known LXC or VM host in config/hosts.yaml"; exit 1; \
	fi; \
	$(LOAD_ENV) cd $(TF_DIR) && terraform apply -target="$$addr"

destroy: ## Destroy all Terraform-managed infrastructure (DANGEROUS)
	$(LOAD_ENV) cd $(TF_DIR) && terraform destroy

## --- Ansible (configuration + application deployment) --------------------

ping: inventory ## Check connectivity to every host in the inventory
	cd $(ANSIBLE_DIR) && ansible all -i $(INVENTORY) -m ping

deploy: apply inventory ## Deploy EVERYTHING: Terraform apply + every Ansible role
	$(LOAD_ENV) cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/site.yaml $(ANSIBLE_EXTRA_VARS)

deploy-%: inventory ## Deploy a single service only, e.g. `make deploy-n8n` (see `make services`)
	$(LOAD_ENV) cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) playbooks/$*.yaml $(ANSIBLE_EXTRA_VARS)

## --- Validation -----------------------------------------------------------

validate: ## Run all local validation (Terraform, Ansible, YAML, shell, Compose)
	./scripts/validation/validate.sh

status: ## Show current Terraform-managed infrastructure
	cd $(TF_DIR) && terraform show
