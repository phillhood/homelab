.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

ANSIBLE_DIR := ansible
TF_DIR      := terraform/environments/kvatch
SITE        := playbooks/site.yaml
BACKUPS     := playbooks/backups.yaml
PIHOLE_IP   := 192.168.1.100
KVATCH_IP   := 192.168.1.101
MUSIC_IP    := 192.168.1.102
FORGE_IP    := 192.168.1.103
REGISTRY_IP := 192.168.1.104
PROXY_IP    := 192.168.1.105
LAB_DOMAIN  := lab.shychedelic.com

UV := uv run --project $(CURDIR)

LIMIT ?=
TAGS  ?=
_LIMIT := $(if $(LIMIT),--limit $(LIMIT),)
_TAGS  := $(if $(TAGS),--tags $(TAGS),)
A      := cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(SITE) $(_LIMIT) $(_TAGS)

.PHONY: help
help:
	@echo ""
	@echo "  Homelab — safe workflow: validate -> backup -> check -> apply -> verify"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next } \
		/^[a-zA-Z0-9_-]+:.*##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "  Narrow any target:  make check LIMIT=pihole TAGS=config"
	@echo ""

##@ Setup

.PHONY: deps
deps: ## Sync the pinned Python toolchain and Ansible collections
	@uv sync
	@cd $(ANSIBLE_DIR) && $(UV) ansible-galaxy collection install -r requirements.yaml
	@$(UV) ansible --version | head -1
	@$(UV) ansible-lint --version | head -1

##@ Validate (never contacts a host)

.PHONY: lint
lint: ## Syntax-check both playbooks, then ansible-lint
	@cd $(ANSIBLE_DIR) && for p in $(SITE) $(BACKUPS); do \
		printf "%-24s " "$$p"; \
		$(UV) ansible-playbook $$p --syntax-check >/dev/null 2>&1 && echo "syntax OK" || { echo "SYNTAX FAIL"; exit 1; }; \
	done
	@cd $(ANSIBLE_DIR) && $(UV) ansible-lint $(SITE) $(BACKUPS)

.PHONY: inventory
inventory: ## Show the inventory graph
	@cd $(ANSIBLE_DIR) && $(UV) ansible-inventory --graph

.PHONY: vars
vars: ## Show every variable per host — decrypts sops secrets, masked by default (SHOW_SECRETS=1 for real values)
	@cd $(ANSIBLE_DIR) && \
	keys=$$(grep -hoE '^[A-Za-z0-9_]+:' inventory/group_vars/*.sops.yaml | tr -d ':' | grep -vx sops | sort -u); \
	if [ "$(SHOW_SECRETS)" = "1" ]; then \
		$(UV) ansible-inventory --graph --vars; \
	else \
		pattern=$$(echo "$$keys" | paste -sd'|'); \
		$(UV) ansible-inventory --graph --vars | sed -E "s/($$pattern) = [^}]*/\1 = <redacted>/g"; \
	fi

.PHONY: tags
tags: ## List the tags available on site.yaml
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(SITE) --list-tags 2>/dev/null | grep -i "TASK TAGS" | sort -u

.PHONY: secrets
secrets: ## Confirm every *.sops.yaml is encrypted at rest
	@for f in $(ANSIBLE_DIR)/inventory/group_vars/*.sops.yaml; do \
		[ -e "$$f" ] || continue; \
		n=$$(grep -c 'ENC\[' "$$f"); \
		printf "%-52s %s\n" "$$f" "$$([ $$n -gt 0 ] && echo "encrypted ($$n)" || echo "PLAINTEXT — DO NOT COMMIT")"; \
	done

##@ Verify (contacts hosts, writes nothing)

.PHONY: ping
ping: ## Connectivity to every SSH-managed host
	@cd $(ANSIBLE_DIR) && $(UV) ansible proxmox:lxc -m ping

.PHONY: check
check: ## Dry run with diffs — what WOULD change
	@$(A) --check --diff

.PHONY: verify
verify: ## Read-only health probes against the real systems
	@printf "%-32s %s\n" "pihole resolves"        "$$(dig +short @$(PIHOLE_IP) kvatch.home)"
	@printf "%-32s %s\n" "pihole filters"         "$$(dig +short @$(PIHOLE_IP) doubleclick.net)"
	@printf "%-32s %s/9\n" "infra dns records"    "$$(for n in router switch ap proxmox kvatch pihole forge registry proxy; do dig +short @$(PIHOLE_IP) $$n.home; done | grep -c '^192')"
	@printf "%-32s %s\n" "pmxcfs symlink intact"  "$$(ssh -o BatchMode=yes root@$(KVATCH_IP) 'test -L /root/.ssh/authorized_keys && echo yes || echo BROKEN')"
	@printf "%-32s %s\n" "lxc timezone"           "$$(cd $(ANSIBLE_DIR) && $(UV) ansible lxc -m command -a 'readlink -f /etc/localtime' 2>/dev/null | tail -1)"
	@printf "%-32s %s\n" "lxc templates"          "$$(cd $(ANSIBLE_DIR) && $(UV) ansible proxmox -m shell -a 'pveam list local | grep -c debian-13' 2>/dev/null | tail -1)"
	@printf "%-32s %s\n" "vm template 9000"       "$$(cd $(ANSIBLE_DIR) && $(UV) ansible proxmox -m shell -a 'qm config 9000 | grep -c template:' 2>/dev/null | tail -1)"
	@printf "%-32s %s\n" "music mount"            "$$(ssh -o BatchMode=yes root@$(KVATCH_IP) 'findmnt -no TARGET /mnt/music || echo MISSING')"
	@printf "%-32s %s\n" "music bind mount"       "$$(ssh -o BatchMode=yes root@$(MUSIC_IP) 'findmnt -no TARGET /srv/music || echo MISSING')"
	@printf "%-32s %s\n" "music smb share"        "$$(ssh -o BatchMode=yes root@$(MUSIC_IP) 'systemctl is-active smbd')"
	@printf "%-32s %s\n" "music syncthing"        "$$(ssh -o BatchMode=yes root@$(MUSIC_IP) 'systemctl is-active syncthing@syncthing')"
	@printf "%-32s %s\n" "music slskd"            "$$(ssh -o BatchMode=yes root@$(MUSIC_IP) 'docker inspect -f "{{.State.Status}}" slskd 2>/dev/null || echo MISSING')"
	@printf "%-32s %s\n" "lab wildcard dns"      "$$(dig +short @$(PIHOLE_IP) probe.$(LAB_DOMAIN))"
	@printf "%-32s %s\n" "caddy"                 "$$(ssh -o BatchMode=yes root@$(PROXY_IP) 'systemctl is-active caddy')"
	@printf "%-32s %s\n" "cert issuer"           "$$(echo | openssl s_client -connect $(PROXY_IP):443 -servername git.$(LAB_DOMAIN) 2>/dev/null | openssl x509 -noout -issuer | sed 's/.*CN=//')"
	@printf "%-32s %s\n" "cert expiry"           "$$(echo | openssl s_client -connect $(PROXY_IP):443 -servername git.$(LAB_DOMAIN) 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)"
	@printf "%-32s %s\n" "zot"                   "$$(ssh -o BatchMode=yes root@$(REGISTRY_IP) 'systemctl is-active zot')"
	@printf "%-32s %s\n" "registry v2"           "$$(curl -s -o /dev/null -w '%{http_code}' https://registry.$(LAB_DOMAIN)/v2/)"
	@printf "%-32s %s\n" "postgresql"            "$$(ssh -o BatchMode=yes root@$(FORGE_IP) 'systemctl is-active postgresql')"
	@printf "%-32s %s\n" "postgres tcp closed"   "$$(ssh -o BatchMode=yes root@$(FORGE_IP) 'ss -lnt | grep -q :5432 && echo OPEN-BAD || echo closed')"
	@printf "%-32s %s\n" "forgejo"               "$$(ssh -o BatchMode=yes root@$(FORGE_IP) 'systemctl is-active forgejo')"
	@printf "%-32s %s\n" "forgejo health"        "$$(curl -s -o /dev/null -w '%{http_code}' https://git.$(LAB_DOMAIN)/api/healthz)"
	@printf "%-32s %s\n" "museek health"         "$$(curl -s -o /dev/null -w '%{http_code}' http://$(MUSIC_IP):8080/healthz)"

.PHONY: idempotent
idempotent: ## Converge twice; fail unless the second run changes nothing
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(SITE) $(_LIMIT) $(_TAGS) >/dev/null
	@out=$$(cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(SITE) $(_LIMIT) $(_TAGS) 2>&1 | grep -E "^[a-z0-9_-]+ +: ok="); \
		echo "$$out"; \
		if echo "$$out" | grep -qE "changed=[1-9]"; then echo ""; echo "NOT IDEMPOTENT — second run made changes"; exit 1; \
		else echo ""; echo "IDEMPOTENT"; fi

##@ Apply

.PHONY: apply
apply: ## Converge the homelab (site.yaml)
	@$(A)

.PHONY: preflight
preflight: lint backup check ## The safe path: lint, take a backup, then show what would change
	@echo ""
	@echo "Backup taken and diffs shown above. Review, then: make apply"

##@ Backups (your revert path)

.PHONY: backup
backup: ## Capture Pi-hole Teleporter + OPNsense config.xml
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS)

.PHONY: backup-pihole
backup-pihole: ## Capture only the Pi-hole Teleporter archive
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags pihole

.PHONY: backup-opnsense
backup-opnsense: ## Capture only the OPNsense config.xml
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags opnsense

.PHONY: backup-music
backup-music: ## Capture only the music library manifest
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags music

.PHONY: backup-forgejo
backup-forgejo: ## Capture only the Forgejo dump
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags forgejo

.PHONY: backups-list
backups-list: ## Show captured backups, newest last
	@find .dev/pihole-backups .dev/opnsense-backups .dev/music-backups .dev/forgejo-backups -type f 2>/dev/null \
		-printf '%TY-%Tm-%Td %TH:%TM  %8s  %p\n' | sort || echo "no backups yet — run: make backup"

##@ Terraform

.PHONY: tf-fmt
tf-fmt: ## Format all Terraform
	@terraform -chdir=$(TF_DIR) fmt -recursive ../..

.PHONY: tf-validate
tf-validate: ## Validate the kvatch environment
	@terraform -chdir=$(TF_DIR) validate

.PHONY: tf-plan
tf-plan: ## Show Terraform drift (read-only)
	@terraform -chdir=$(TF_DIR) plan
