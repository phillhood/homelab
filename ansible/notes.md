### initial steps, for ansible later

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



