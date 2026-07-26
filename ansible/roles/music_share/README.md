# music_share

Samba and Syncthing inside CT 101. Layered on `debian_lxc_base`.

## The permission model

Every writer — Samba, Syncthing, slskd, the custom app — is in group `music`, GID 1500.

- Directories are `2775`. The setgid bit makes new entries inherit group `music`.
- Writers run `umask 002`.
- Samba enforces it server-side too (`force group`, `create mask = 0664`,
  `force create mode = 0664`, `directory mask = 2775`, `force directory mode = 2775`),
  so a client with a careless umask still cannot create a file the other services
  cannot modify.

Net effect: anything any writer creates stays group-writable by every other writer,
permanently. That is the property to re-test after touching any of these values:

```bash
smbclient //192.168.1.102/music -U phill -c 'cd downloads/complete; put /etc/hostname t.txt'
ssh root@192.168.1.102 'ls -l /srv/music/downloads/complete/t.txt'   # expect group music, 0664
```

## The share covers the whole tree

`[music]` maps `/srv/music`, not just `library/`, so promoting a finished download from
`downloads/complete/` into `library/` is a drag in Finder rather than an SSH session.

## macOS

`vfs objects = catia fruit streams_xattr` with `fruit:metadata = stream` and
`fruit:posix_rename = yes`. Without these, Finder scatters `._` files through the library
and occasionally fails renames.

## Syncthing direction is not a preference

The NAS folder is **Send Only**; every client is **Receive Only**. This makes conflicts
structurally impossible — SMB is the single write path. Do not flip a client to Send
Receive to "fix" a sync problem; that reintroduces the conflict class the design removed.

## Pairing a client (manual)

Automating this would need each client's device ID, which only exists after the client
is installed. Per spec §13 it stays manual:

1. Open `http://192.168.1.102:8384` and log in.
2. **Add Remote Device**, paste the client's device ID.
3. Share the `music-library` folder with it.
4. On the client, accept, and set the folder type to **Receive Only**.
5. For selective sync, put a `.stignore` in the client's folder — negations first, then
   a catch-all:

   ```
   !/Boards of Canada
   !/Autechre
   *
   ```

Global discovery and relaying are left on so the Mac syncs away from home. Forwarding
`22000` gives direct rather than relay-speed transfers; optional.

## Why config.xml is edited with the xml module

Syncthing rewrites its own config, so a full template would fight it on every restart.
`syncthing generate` creates the file once (guarded by `creates:`), then only the few
settings that matter — GUI address, the library folder — are set with
`community.general.xml`, which converges instead of overwriting.

**The config lives at `/var/lib/syncthing/.local/state/syncthing/config.xml`** — the XDG
state directory, not `.config/syncthing`. Syncthing moved in 1.27. `generate` takes
`--config=`, not the deprecated `--home=`.

`community.general.xml` needs `python3-lxml` on the target, which the Debian 13 LXC
template does not ship; the apt task installs it.

## Verifying the GUI is actually protected

`curl http://192.168.1.102:8384/` returns **200** even unauthenticated — that is the SPA
shell and proves nothing. Authentication is enforced at the API:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://192.168.1.102:8384/rest/system/config
```

Expect **403**. A 200 there means the GUI is open.

## Secrets never travel in argv

Both password paths deliver via stdin, never as command arguments — `smbpasswd -s -a`
reads from `stdin:`, and `syncthing generate` takes `--gui-password=-`. A password passed
as an argument sits in `/proc/<pid>/cmdline` for the life of the process, readable by any
local process; `no_log: true` hides it from Ansible's output and does nothing about the
OS process table. Keep both that way.

Note CT 101 has **no `sudo`**. Running a task as the `syncthing` service account needs
`become_method: ansible.builtin.su` with `become_flags: "-s /bin/sh"`, because the account
is `nologin` and plain `su -c` would try to execute through it.

## Rotating the Samba password

`pdbedit -L -u` only tests whether the user *exists*, so changing `music_smb_password` in
sops and re-applying reports `changed=0` while the live password silently diverges. Force
it:

```bash
ansible-playbook playbooks/music.yaml --limit music1 --tags samba -e music_smb_reset_password=true
```

Same shape as `pihole_reset_password` in the `pihole` role.

## `.state/` is vetoed from the share

`veto files = /.state/` keeps museek's SQLite job store out of SMB. Spotlight indexes
mounted shares and Time Machine tries to back them up, and neither should be touching a
live database; a user with "show hidden files" on tidying away what looks like clutter is
the other half. `.meta/` is deliberately left visible — backup manifests are static output
worth browsing.
