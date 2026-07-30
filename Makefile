.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

ANSIBLE_DIR  := ansible
TF_DIR       := terraform/environments/kvatch
SITE         := playbooks/site.yaml
BACKUPS      := playbooks/backups.yaml
PIHOLE_IP    := 192.168.1.100
KVATCH_IP    := 192.168.1.101
MUSIC_IP     := 192.168.1.102
FORGE_IP     := 192.168.1.103
REGISTRY_IP  := 192.168.1.104
PROXY_IP     := 192.168.1.105
PAULT_IP     := 192.168.1.106
PAULT_STAGING_IP := 192.168.1.108
HEADSCALE_IP := 192.168.1.107
PAULT_VARS   := $(ANSIBLE_DIR)/inventory/host_vars/pault.yaml
PAULT_HOST   := pault.ca
PAULT_MEDIA  := media.pault.ca
PAULT_REPO   ?= $(HOME)/Dev/phillhood/pault
SHA          ?= $(shell git -C $(PAULT_REPO) rev-parse --short=8 HEAD 2>/dev/null)
LAB_DOMAIN   := lab.shychedelic.com
VPN_HOST     := vpn.shychedelic.com
RESTIC_REPO  := /var/backups/restic/music
RESTIC_PW    := /etc/music-backup/repo-password

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
lint: ## Syntax-check every playbook, then ansible-lint
	@cd $(ANSIBLE_DIR) && for p in playbooks/*.yaml; do \
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
	keys=$$(grep -hoE '^[A-Za-z0-9_]+:' inventory/group_vars/*.sops.yaml inventory/host_vars/*.sops.yaml | tr -d ':' | grep -vx sops | sort -u); \
	if [ "$(SHOW_SECRETS)" = "1" ]; then \
		$(UV) ansible-inventory --graph --vars; \
	else \
		pattern=$$(echo "$$keys" | paste -sd'|'); \
		$(UV) ansible-inventory --graph --vars | sed -E "s/($$pattern) = [^}]*/\1 = <redacted>/g"; \
	fi

.PHONY: tags
tags: ## List the tags available on site.yaml and backups.yaml
	@for p in $(SITE) $(BACKUPS); do \
		printf "\n  %s\n" "$$p"; \
		cd $(CURDIR)/$(ANSIBLE_DIR) && $(UV) ansible-playbook $$p --list-tags 2>/dev/null \
			| grep -i "TASK TAGS" | sort -u | sed 's/^/  /'; \
	done

.PHONY: secrets
secrets: ## Confirm every *.sops.yaml is encrypted at rest
	@for f in $(ANSIBLE_DIR)/inventory/group_vars/*.sops.yaml $(ANSIBLE_DIR)/inventory/host_vars/*.sops.yaml; do \
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
	@printf "%-32s %s/13\n" "infra dns records"   "$$(for n in router switch ap proxmox kvatch pihole music forge registry proxy pault pault-staging headscale; do dig +short @$(PIHOLE_IP) $$n.home; done | grep -c '^192')"
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
	@printf "%-32s %s\n" "museek health"         "$$(ssh -o BatchMode=yes root@$(MUSIC_IP) 'docker inspect museek' >/dev/null 2>&1 && curl -s -o /dev/null -w '%{http_code}' http://$(MUSIC_IP):8080/healthz || echo gated)"
	@printf "%-32s %s\n" "pault minio"           "$$(ssh -o BatchMode=yes root@$(PAULT_IP) 'docker inspect -f "{{.State.Status}}" pault-minio 2>/dev/null || echo MISSING')"
	@printf "%-32s %s\n" "pault minio 9001 shut" "$$(ssh -o BatchMode=yes root@$(PAULT_IP) 'ss -lnt | grep -q :9001 && echo OPEN-BAD || echo closed')"
	@printf "%-32s %s\n" "pault bucket"          "$$(curl -s -o /dev/null -w '%{http_code}' http://$(PAULT_IP):9000/minio/health/live)"
	@printf "%-32s %s\n" "pault cloudflared"     "$$(ssh -o BatchMode=yes root@$(PAULT_IP) 'docker inspect -f "{{.State.Status}}" pault-cloudflared 2>/dev/null || echo MISSING')"
	@printf "%-32s %s\n" "pault media public"    "$$(curl -s -o /dev/null -w '%{http_code}' https://$(PAULT_MEDIA)/minio/health/live)"
	@printf "%-32s %s\n" "pault public"          "$$(curl -s -o /dev/null -w '%{http_code}' https://$(PAULT_HOST)/)"
	@printf "%-32s %s\n" "pault web digest"      "$$(ssh -o BatchMode=yes root@$(PAULT_IP) 'docker image inspect -f "{{index .RepoDigests 0}}" $$(docker inspect -f "{{.Image}}" pault-web) 2>/dev/null || echo gated' | tail -1)"
	@printf "%-32s %s\n" "pault api digest"      "$$(ssh -o BatchMode=yes root@$(PAULT_IP) 'docker image inspect -f "{{index .RepoDigests 0}}" $$(docker inspect -f "{{.Image}}" pault-api) 2>/dev/null || echo gated' | tail -1)"
	@printf "%-32s %s\n" "pault lab"             "$$(curl -s https://pault.$(LAB_DOMAIN)/ | head -c 20)"
	@printf "%-32s %s\n" "headscale"             "$$(ssh -o BatchMode=yes root@$(HEADSCALE_IP) 'systemctl is-active headscale')"
	@printf "%-32s %s\n" "headscale health"      "$$(curl -s -o /dev/null -w '%{http_code}' http://$(HEADSCALE_IP):8080/health)"
	@printf "%-32s %s\n" "headscale nodes"       "$$(ssh -o BatchMode=yes root@$(HEADSCALE_IP) 'headscale nodes list' 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^[0-9]+ +\|' || echo 0)"
	@printf "%-32s %s\n" "headscale lab tls"     "$$(curl -s -o /dev/null -w '%{http_code}' https://$(VPN_HOST)/health)"
	@printf "%-32s %s\n" "headscale public"      "$$(curl -s -o /dev/null -w '%{http_code}' --resolve $(VPN_HOST):443:$$(dig +short $(VPN_HOST) @1.1.1.1 | tail -1) https://$(VPN_HOST)/health)"
	@printf "%-32s %s\n" "ddns record current"   "$$(w=$$(curl -s --max-time 8 https://ifconfig.me); r=$$(dig +short A $(VPN_HOST) @1.1.1.1 | tail -1); if [ -z "$$w" ] || [ -z "$$r" ]; then echo unknown; elif [ "$$w" = "$$r" ]; then echo current; else echo "STALE-BAD $$r != $$w"; fi)"
	@printf "%-32s %s\n" "public listener tight" "$$(out=$$(curl -sk -D - -o /dev/null -w '%{size_download}' --resolve git.$(LAB_DOMAIN):8443:$(PROXY_IP) https://git.$(LAB_DOMAIN):8443/ 2>/dev/null); if echo "$$out" | grep -qi '^via:' || [ "$$(echo "$$out" | tail -1)" != 0 ]; then echo LEAKING-BAD; else echo closed; fi)"
	@printf "%-32s %s\n" "kvatch tailscaled"     "$$(ssh -o BatchMode=yes root@$(KVATCH_IP) 'systemctl is-active tailscaled')"
	@printf "%-32s %s\n" "kvatch tailnet state"  "$$(ssh -o BatchMode=yes root@$(KVATCH_IP) 'tailscale status --json' 2>/dev/null | sed -n 's/.*"BackendState": "\([^"]*\)".*/\1/p' | head -1)"
	@printf "%-32s %s\n" "subnet route approved" "$$(ssh -o BatchMode=yes root@$(HEADSCALE_IP) 'headscale nodes list-routes' 2>/dev/null | grep -c '192.168.1.0/24' || echo 0)"

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

.PHONY: pault
pault: ## Redeploy the pault stack, repinned to the pault repo's HEAD. SHA= overrides
	@if [ -z "$(SHA)" ]; then echo "No SHA resolved from $(PAULT_REPO); deploying the pinned images"; fi
	@if [ -n "$(SHA)" ]; then \
	  for svc in web api; do \
	    repo=$$(sed -n "s|^pault_$${svc}_image: \(.*\):[^:]*$$|\1|p" $(PAULT_VARS)); \
	    [ -n "$$repo" ] || { echo "pault_$${svc}_image is not a tagged reference" >&2; exit 1; }; \
	    docker manifest inspect "$$repo:$(SHA)" >/dev/null 2>&1 \
	      || { echo "$$repo:$(SHA) is not in the registry" >&2; exit 1; }; \
	  done; \
	  for svc in web api; do \
	    repo=$$(sed -n "s|^pault_$${svc}_image: \(.*\):[^:]*$$|\1|p" $(PAULT_VARS)); \
	    sed -i "s|^pault_$${svc}_image: .*|pault_$${svc}_image: $$repo:$(SHA)|" $(PAULT_VARS); \
	  done; \
	  test $$(grep -cE "^pault_(web|api)_image: .*:$(SHA)$$" $(PAULT_VARS)) -eq 2 \
	    || { echo "repin did not take" >&2; exit 1; }; \
	  grep -E "^pault_(web|api)_image:" $(PAULT_VARS); \
	fi
	@$(MAKE) --no-print-directory apply LIMIT=pault TAGS=compose

.PHONY: preflight
preflight: lint backup check ## The safe path: lint, take a backup, then show what would change
	@echo ""
	@echo "Backup taken and diffs shown above. Review, then: make apply"

##@ Backups (your revert path)

.PHONY: backup
backup: ## Capture every series: Pi-hole, OPNsense, music, Forgejo, Terraform state
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS)

.PHONY: backup-pihole
backup-pihole: ## Capture only the Pi-hole Teleporter archive
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags pihole

.PHONY: backup-opnsense
backup-opnsense: ## Capture only the OPNsense config.xml
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags opnsense

.PHONY: backup-music
backup-music: ## Capture only the music library manifest — what you had, not the files
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags music

.PHONY: backup-music-content
backup-music-content: ## Capture the music files themselves into the restic repo on kvatch
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags music-content

.PHONY: music-snapshots
music-snapshots: ## Show the restic snapshots holding the music library
	@$(KVATCH_SSH) 'RESTIC_PASSWORD_FILE=$(RESTIC_PW) restic -r $(RESTIC_REPO) snapshots --tag music' \
		|| echo "  no repository yet — run: make backup-music-content"

.PHONY: music-restore
music-restore: ## Restore the music library from restic (SNAPSHOT=latest DEST=/mnt/music-restore)
	@test -n "$(DEST)" || { echo "  usage: make music-restore DEST=<path> [SNAPSHOT=latest]"; exit 1; }
	@$(KVATCH_SSH) 'RESTIC_PASSWORD_FILE=$(RESTIC_PW) restic -r $(RESTIC_REPO) \
		restore $(or $(SNAPSHOT),latest) --target $(DEST)'

.PHONY: backup-forgejo
backup-forgejo: ## Capture only the Forgejo dump
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags forgejo

.PHONY: backup-terraform
backup-terraform: ## Capture only the Terraform state + its recovery script
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags terraform

.PHONY: backup-headscale
backup-headscale: ## Capture only the headscale database and keys
	@cd $(ANSIBLE_DIR) && $(UV) ansible-playbook $(BACKUPS) --tags headscale

.PHONY: backups-list
backups-list: ## Show captured backups, newest last
	@find .dev/pihole-backups .dev/opnsense-backups .dev/music-backups .dev/forgejo-backups .dev/terraform-backups .dev/headscale-backups -type f 2>/dev/null \
		-printf '%TY-%Tm-%Td %TH:%TM  %8s  %p\n' | sort || echo "no backups yet — run: make backup"

##@ Snapshots (the revert path for guest OS upgrades)

KVATCH_SSH := ssh -o BatchMode=yes root@$(KVATCH_IP)
SNAP       ?= preupgrade
_CT_NAME    = name=$$($(KVATCH_SSH) "pct config $(CT) 2>/dev/null | sed -n 's/^hostname: //p'"); \
              test -n "$$name" || { echo "  CT '$(CT)' not found on $(KVATCH_IP) — run: make snapshots"; exit 1; }
_NEED_CT    = @test -n "$(CT)" || { echo "  usage: make $@ CT=<vmid> [SNAP=$(SNAP)]"; echo ""; \
              $(MAKE) --no-print-directory snapshots; exit 1; }

.PHONY: snapshots
snapshots: ## Show every container, its snapshots, and thin-pool headroom
	@$(KVATCH_SSH) 'for id in $$(pct list | tail -n +2 | awk "{print \$$1}"); do \
		printf "  CT %-5s %s\n" "$$id" "$$(pct config $$id | sed -n "s/^hostname: //p")"; \
		pct listsnapshot $$id 2>/dev/null | sed "s/^/        /"; \
	done; \
	printf "\n  thin pool  %s\n" "$$(lvs --noheadings -o data_percent,metadata_percent pve/data | tr -s " ")"'

.PHONY: snapshot
snapshot: ## Snapshot a container before upgrading it (CT=104 [SNAP=preupgrade])
	$(_NEED_CT)
	@$(_CT_NAME); \
	mp=$$($(KVATCH_SSH) "pct config $(CT) | grep -E '^mp[0-9]+:' || true"); \
	if [ -n "$$mp" ]; then \
		echo ""; \
		echo "  REFUSING: CT $(CT) ($$name) has a bind mount, so Proxmox cannot"; \
		echo "  snapshot it — it has no way to snapshot a host directory:"; \
		echo "      $$mp"; \
		echo ""; \
		echo "  There is NO snapshot revert path for this container. Use vzdump"; \
		echo "  (which skips bind mounts) or an app-level backup, and be aware"; \
		echo "  that anything not reproduced by Ansible is unprotected."; \
		echo "  See the debian_lxc_base role notes."; \
		echo ""; \
		exit 1; \
	fi; \
	echo "  CT $(CT) ($$name) -> snapshot '$(SNAP)'"; \
	$(KVATCH_SSH) "pct snapshot $(CT) $(SNAP)" && \
	echo "  taken. revert with: make rollback CT=$(CT) SNAP=$(SNAP)"

.PHONY: unsnapshot
unsnapshot: ## Drop a snapshot once the upgrade is verified (CT=104 [SNAP=preupgrade])
	$(_NEED_CT)
	@$(_CT_NAME); \
	echo "  CT $(CT) ($$name) -> dropping '$(SNAP)'. The revert path goes away."; \
	$(KVATCH_SSH) "pct delsnapshot $(CT) $(SNAP)" && echo "  dropped."

.PHONY: rollback
rollback: ## DESTRUCTIVE: stop, roll back to snapshot, restart (CT=104 [SNAP=preupgrade])
	$(_NEED_CT)
	@$(_CT_NAME); \
	echo ""; \
	echo "  This STOPS CT $(CT) ($$name), DISCARDS every change since '$(SNAP)',"; \
	echo "  and starts it again. Rollback cannot run against a live container."; \
	if [ "$(CT)" = "100" ]; then \
		echo ""; \
		echo "  CT 100 is Pi-hole. DHCP advertises 192.168.1.100 as the only resolver,"; \
		echo "  so ALL LAN DNS fails for the duration."; \
	fi; \
	echo ""; \
	read -r -p "  Type the hostname ($$name) to confirm: " ans; \
	test "$$ans" = "$$name" || { echo "  aborted — nothing changed."; exit 1; }; \
	$(KVATCH_SSH) "pct stop $(CT) && pct rollback $(CT) $(SNAP) && pct start $(CT)" && \
	echo "  rolled back. Give services a moment, then: make verify"

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
