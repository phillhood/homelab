# Fresh PVE Setup

To be translated into ansible playbooks

### Set up terraform user and permissions
1. created dedicated tf user for tightly scoped acl

    `pveum user add terraform@pve`

2. custom role for terraform permissions

    `pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use`

3. grant role at root for for cluster-wide scope

    `pveum aclmod / -user terraform@pve -role Terraform`

4. Create an API token for that user (note: 'privsep=0' means the token inherits the user's full privileges)
    
    `pveum user token add terraform@pve provider --privsep 0`

5. result
```
user: terraform@pve
role: Terraform
full-tokenid: terraform@pve!provider
info: {"privsep":"0"}
secret: (in lab vault) TODO: put in .tfvars/env later
```

### Download template for Pihole and apply


1. download current debian 13-standard_* 
manually checked with `pveam available | grep debian-13` --> debian-13-standard_13.1-2_amd64.tar.szt

    `dpveam download local debian-13-standard_13.1-2_amd64.tar.szt`

2. apply terraform pihole module - see terraform modules and environment
    `terraform plan`
    `terraform apply` -> yes

> [!NOTE] 
> came across warning applying pihole tf configuration
>
> ```WARN: Systemd 257 detected. You may need to enable nesting.```
> - after digging around proxmox forums and reddit and only finding tangential but not directly related issues, my boy claude had this to say: 
>
    >Debian 13 ships systemd 257, and modern systemd wants user-namespace nesting enabled to run cleanly inside an unprivileged container. Without nesting=1, some systemd units can misbehave — journald, resolved, timers, that kind of thing. For Pi-hole specifically, the core DNS function (dnsmasq/FTL) will run fine, but you may see systemd complaints in the logs and occasional flakiness in services that lean on newer systemd features.
>
>- tried passing `nesting = true` via pihole tf module just in case, but of course tf sets the other flags in the features block that aren't allowed *(this is a bad idea... thanks claude... see below)*
>```
>│ Error: All attempts fail:
>│ #1: received an HTTP 403 response - Reason: Permission check failed (changing feature flags (except nesting) is only allowed for root@pam)
>```
>- "(except nesting)"" yeyeyeye for sure for sure for sure
>- unpriviledged is a must to avoid passing root pass to tf / lxcs..  sick
>-  ~~fix for now was to run the following directly on the host:~~
>
>    ~~pct set 100 -features nesting=1~~
>
>    ~~pct reboot 100~~
>
>- ~~this is manually-induced drift though~~
>- ~~TODO: revisit this if provider gets updated?~~
>- ~~ideally avoid needing manual steps to correct: will have to make this a step via ansible~~
>- guess not actually: [its nitpicky for a homelab but trying to learn best practices here so.. ](https://diymediaserver.com/post/upgrade-debian-12-to-13-proxmox-lxc-243-credentials-fix/)
    >- article mentions doing some jank inside the container but this is supposed to be an excercise in declarative IaC, so just going to drop it in from the host via ansible in the future and call it a day..
>    - great use of 2 hours, maybe i just go back to vibe-coding arch rices...
>    - including the steps for reference in the future (don't actually do this, causes other headaches that aren't worth repeating/explaining during pihole installation later)
>
    >1. get the generator: `curl -fsSL https://sources.debian.org/data/main/d/distrobuilder/3.2-2/distrobuilder/lxc.generator -o /tmp/lxc.generator` 
>    2. shove it in there: `pct exec 100 -- mkdir -p /etc/systemd/system-generators`
    >3. fix perms: `pct push 100 /tmp/lxc.generator /etc/systemd/system-generators/lxc --perms 0755`
    >4. mask some mounts that will scream despite being provided already: `pct exec 100 -- systemctl mask dev-mqueue.mount run-lock.mount tmp.mount`
>    5. reboot for gen to run, ignore warnings until after reboot: `pct reboot 100`
>    6. wait until it's back, check if it worked: `pct exec 100 -- systemctl --failed`
>  
>  #### To sum up: choosing to not proceed with any of this, will monitor pihole container for errors - quirk of modern systemd in such an environment I guess - no evidence this will be a problem right now, don't want to start elevating privs or introducing manual fixes/drift without evidence that it's explicitly required... summary in obsidian, moving on 
>  ---
>

### Set up Pihole container

1. install prereqs inside pihole container, and run pihole install script
    `pct enter 100`
    `apt update && apt install -y curl`
    `curl -sSL https://install.pi-hole.net | bash 2>&1 | tee /tmp/pihole-install.log`

2. manual set up this time - TODO: try passing configs via non-interactive before ansible implementation