# music_share

Samba and Syncthing inside CT 101. Layered on `debian_lxc_base`.

## Usage

| Tag | Does |
|---|---|
| `users` | the `music` group and the Samba service user |
| `samba` | Samba, `smb.conf`, the share password |
| `syncthing` | Syncthing, its config, the library folder |
| `share` | all three |

```bash
# rotate the Samba password after changing it in sops
ansible-playbook playbooks/music.yaml --limit music1 --tags samba \
  -e music_smb_reset_password=true
```

The share maps `/srv/music`, not just `library/`, so promoting a finished download from
`downloads/complete/` is a drag in Finder rather than an SSH session.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `music_share_name` | `music` | |
| `music_smb_user` | `phill` | |
| `music_smb_reset_password` | `false` | see invariants |
| `music_syncthing_user` | `syncthing` | |
| `music_syncthing_home` | `/var/lib/syncthing` | |
| `music_syncthing_config_dir` | `<home>/.local/state/syncthing` | XDG state, **not** `.config` |
| `music_syncthing_gui_port` | `8384` | |
| `music_syncthing_folder_id` | `music-library` | |

`music_gid` and `music_container_mount` come from `group_vars/music_common.yaml`.

**Requires** `music_smb_password` and `syncthing_gui_password` from `music.sops.yaml`.

## Pairing a client (manual)

Automating this would need each client's device ID, which only exists after the client is
installed.

1. Open `http://192.168.1.102:8384` and log in.
2. **Add Remote Device**, paste the client's device ID.
3. Share the `music-library` folder with it.
4. On the client, accept, and set the folder type to **Receive Only**.
5. For selective sync, put a `.stignore` in the client's folder — negations first, then a
   catch-all:

   ```
   !/Boards of Canada
   !/Autechre
   *
   ```

Global discovery and relaying are left on so the Mac syncs away from home. Forwarding
`22000` gives direct rather than relay-speed transfers; optional.

## Invariants

- **The NAS folder is Send Only and every client is Receive Only.** This makes conflicts
  structurally impossible — SMB is the single write path. Do not flip a client to Send
  Receive to "fix" a sync problem; that reintroduces the entire conflict class the design
  removed.
- **Every writer is in group `music` (GID 1500), directories are `2775`, writers run
  `umask 002`, and Samba enforces the same server-side** (`force group`,
  `create mask = 0664`, `force create mode = 0664`, `directory mask = 2775`,
  `force directory mode = 2775`). Net effect: anything any writer creates stays
  group-writable by every other writer, permanently. Re-test after touching any of those
  values:

  ```bash
  smbclient //192.168.1.102/music -U phill -c 'cd downloads/complete; put /etc/hostname t.txt'
  ssh root@192.168.1.102 'ls -l /srv/music/downloads/complete/t.txt'   # expect group music, 0664
  ```

- **Secrets never travel in argv.** `smbpasswd -s -a` reads from `stdin:`, and
  `syncthing generate` takes `--gui-password=-`. An argument sits in `/proc/<pid>/cmdline`
  for the life of the process, readable by any local process; `no_log` hides it from
  Ansible's output and does nothing about the process table.
- **`pdbedit -L -u` only tests whether the user exists**, so changing `music_smb_password`
  in sops and re-applying reports `changed=0` while the live password silently diverges.
  Force it with `music_smb_reset_password=true`.
- **Syncthing's config is edited with the `xml` module, never templated.** Syncthing
  rewrites its own config, so a full template would fight it on every restart.
  `syncthing generate` creates the file once behind `creates:`, then only the settings that
  matter are converged.
- **A `200` from `:8384/` does not mean the GUI is protected** — that is the SPA shell.
  Authentication is enforced at the API: `curl -o /dev/null -w '%{http_code}'
  http://192.168.1.102:8384/rest/system/config` must return **403**.
- **`veto files = /.state/`** keeps museek's SQLite job store out of SMB — Spotlight indexes
  mounted shares and Time Machine tries to back them up, and neither should touch a live
  database. `.meta/` is deliberately left visible.
- CT 101 has no `sudo`, so running a task as the `syncthing` account needs
  `become_method: ansible.builtin.su` **and** `become_flags: "-s /bin/sh"`, because that
  account is `nologin`.

Rationale and the macOS vfs settings are in the local notes for this role.
