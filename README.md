# Homelab

***v2!***


### Unncessary Backstory

I learned a lot with my first setup, but it's time to move on. I thought I was too cool for Proxmox - pure bare metal sounded way cooler - and ran k3s + docker across my hodgepodge of devices. 

YOLOd it and had a lot of fun, but took on too much too quickly. Ultimately it was not implemented well (shocker) and it ended up being too rigid as it grew, resulting in me having less patience to experiment. 

Figured it was time for a change, plus my office was getting real hot...

So we go again!

---


## Overview

#### Nodes

> TODO: table of devices with specs

#### Services

> TODO: table of technologies with links

#### Network

> TODO: topology diagrams, status indicators


## Plan + Goals


### Phase 1 - Base setup, single node
> Goal: learn the basics of proxmox ve, reunite with terraform ✓
- [x] Install Proxmox VE on initial node
  - [x] Configure WebUI and SSH
- [x] Terraform setup
  - [x] PVE provider, token + ssh


### Phase 2 - LXC + VM Templates
> Goal: play around with vms and containers, record manual process to automate with ansible later ✓
- [x] Terraform configs
  - [x] kvatch environment
- [x] Set up pi-hole module
  - [x] Create LXC template
  - [x] Deploy pi-hole
  - [x] Recover backup configs, IPs, logs
  - [x] Restore DNS IP in OPNsense
  - [x] Backup new black/white lists, regex, local dns
- [x] Base VM template
    - [x] test vm deploy for now


### Phase 3 - Ansible + add node(s)
> Goal: learn the proper workflow, foundation to add back my nodes quickly
- [x] Setup base/empty stubs
- [x] Proxmox host playbooks
  - [x] Repos
  - [x] Root keys, dns config
  - [x] Terraform user, role, token
  - [x] LXC template
  - [x] VM template
- [x] Pi-hole playbooks
  - [x] install, config, gravity, password


### Phase 3.5 - Music NAS

- [x] 2 TB NVMe formatted ext4, label `music`, 1 inode/MiB
- [x] Thunderbolt enclosure enrolled via `bolt`, policy auto
- [x] Host mount on kvatch, `/mnt/music`, layout + ownership
- [x] CT 101 `music` via Terraform
- [x] Bind mount + nesting/keyctl via Ansible `pct set`
- [x] Samba share, macOS-safe
- [x] Syncthing send-only library folder
- [x] Docker + slskd stack
- [x] Library manifest backup
- [ ] OPNsense port forward for 2235/tcp (manual)
- [ ] Pair the Mac and Linux laptop with Syncthing (manual)
- [ ] Custom downloader app image (`music_app_image`)


### Phase 4 - Flux
> Goal: learn another GitOps framework - leaner and more homelab-friendly than ArgoCD
- [ ] TODO: this task list


### Phase 5 - k8s via Talos Linux 
> Goal: Learn a new way of approaching k8s management, and offset VM overhead
- [ ] TODO: this task list


### Phase 6 - FOSS services + add node(s)
> Goal: Trim down my absurd stack of services from last time, find new ones, fine tune them to perfection
- [ ] TODO: this task list


### Phase ???
> Goal: come up with more goals, learn more things, find reasons to spend more money on hardware
- [ ] TODO: this task list


## Networking ToDos
OPNsense router
- [x] Update 
  - [x] Firmware 
  - [x] Legacy DHCP migration to Dnsmasq
  - [x] Remove legacy ISC DHCP service
  - [x] Update VLANs with switch
  - [x] Manual config backup
- [x] Automate backups via API
  - [x] Create backup user, scope, group
  - [x] Define ansible playbook task
    - [ ] Setup cron
  

TP-Link managed switch
- [x] Update firmware
- [x] Update VLANs with router
- [x] Backup configs



