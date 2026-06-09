# Windows-Specific Docker Gotchas

> Issues that only happen (or matter most) on Windows + Docker Desktop + WSL2.
> Owner is on Windows 11. This is critical reference.

---

## 1. WSL2 backend (default in Docker Desktop)

Docker Desktop on Windows runs the docker daemon inside a WSL2 distribution (not Hyper-V VM). This means:

- All containers run on Linux, even when Docker Desktop UI shows Windows
- File system performance depends on WHERE the files live (Windows FS vs WSL FS)
- The "host" from a container's perspective is the WSL2 VM, not Windows

### Performance implications

| Mount source | Performance | Use case |
|---|---|---|
| `\\wsl$\Ubuntu\home\user\proj` (WSL filesystem) | ⚡ Fast | Dev with hot reload, large repos |
| `C:\Users\jerb2\proj` (Windows filesystem) | 🐌 Slow (5-50x slower) | Only when you must access from Windows tools |
| Named volume (`docker volume create`) | ⚡ Fast | Production-style, no host access |

**Recommendation**: clone your dev repos INSIDE WSL2:
```bash
# In WSL2 terminal:
cd ~
git clone <repo>
code .  # opens in VS Code via WSL remote — best of both worlds
```

Then bind mount from inside WSL:
```bash
docker run -v $(pwd):/app myapp  # in WSL terminal, $(pwd) is /home/user/repo
```

---

## 2. Path translation in bind mounts

When you run `docker` from different shells, the paths translate differently:

### From PowerShell

```powershell
# Windows-style paths work
docker run -v C:\Users\jerb2\proj:/app myapp
docker run -v "${PWD}:/app" myapp   # PowerShell's $PWD = C:\... format

# Forward slashes also work
docker run -v C:/Users/jerb2/proj:/app myapp
```

### From Git Bash / WSL

```bash
# Linux-style paths
docker run -v /c/Users/jerb2/proj:/app myapp     # Git Bash translates /c/ → C:\
docker run -v /home/user/proj:/app myapp         # WSL native path

# DON'T use $(pwd) blindly — depends on shell:
# - Git Bash $(pwd) might be /c/Users/...
# - WSL $(pwd) might be /home/user/...
# - PowerShell uses ${PWD} with different format
```

### From CMD

```cmd
docker run -v %cd%:/app myapp
```

**Gotcha**: paths with spaces require quoting. `C:\Program Files\proj` → `"C:\Program Files\proj"` in PowerShell, escape carefully in bash.

---

## 3. Case sensitivity

Windows filesystem is **case-insensitive** (NTFS by default). Linux containers are **case-sensitive**. This bites:

```bash
# On Windows host, file is `Config.json`
# In Dockerfile: COPY config.json .   ← works on host, fails inside container if other code does require('./Config.json')
```

**Fixes**:
1. Adopt all-lowercase filenames in repos (recommended for cross-platform)
2. Configure WSL2 to enable case sensitivity per-directory:
   ```bash
   wsl
   fsutil.exe file setCaseSensitiveInfo /mnt/c/path/to/dir enable
   ```
3. CI should run on Linux to catch these before they hit prod

---

## 4. Line endings (CRLF vs LF)

Windows defaults to CRLF (`\r\n`). Linux containers expect LF (`\n`). When you copy a shell script from Windows into a container:

```dockerfile
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
CMD ["/usr/local/bin/entrypoint.sh"]
```

If `entrypoint.sh` has CRLF endings, you get cryptic error:
```
exec /usr/local/bin/entrypoint.sh: no such file or directory
```

(The `\r` at line end becomes part of the shebang path, breaking the lookup.)

**Fixes**:
1. Configure `.gitattributes` in repo:
   ```
   * text=auto eol=lf
   *.sh text eol=lf
   Dockerfile text eol=lf
   ```
2. Convert during build:
   ```dockerfile
   RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh
   ```
3. Git config global:
   ```bash
   git config --global core.autocrlf input  # convert CRLF→LF on commit, no conversion on checkout
   ```

---

## 5. Docker Desktop file sharing settings

Docker Desktop has a "Resources → File sharing" panel. Only listed drives/paths are mountable as bind volumes. By default, your user profile is shared.

If you get `Mounts denied: The path /c/Users/... is not shared from the host`:
1. Docker Desktop → Settings → Resources → File sharing
2. Add the drive/path you need
3. Apply & Restart

---

## 6. Port conflicts with Windows services

Common collisions:
- Port 80, 443: IIS (if installed), other web servers
- Port 5432: native PostgreSQL install
- Port 3306: native MySQL/MariaDB install
- Port 6379: native Redis install
- Port 27017: native MongoDB install

Diagnose:
```powershell
netstat -ano | findstr :PORT
# Get-Process -Id <PID> to find owner
```

Stop the Windows service if it's docker-managed:
```powershell
# Stop service (current session)
Stop-Service postgresql-x64-17
# Disable on boot
Set-Service postgresql-x64-17 -StartupType Disabled
```

Or just remap container ports:
```bash
docker run -p 5433:5432 postgres  # use 5433 on host
```

---

## 7. localhost from container to Windows host

`localhost` inside a container is the container itself, not Windows.

To reach Windows host from container:
- Docker Desktop provides `host.docker.internal` DNS name → resolves to host IP
- Example: `curl http://host.docker.internal:5432` from container reaches Windows port 5432

```dockerfile
# Or pass explicitly
docker run --add-host=host.docker.internal:host-gateway myapp  # works on Linux too
```

---

## 8. Docker daemon disk usage (WSL2 VHDX)

Docker stores all images, containers, volumes inside a virtual disk:
```
%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx
```

The VHDX grows dynamically but **doesn't auto-shrink** after pruning inside Docker. So:
- `docker system prune -a` reclaims space INSIDE the WSL VM
- The VHDX file on Windows disk stays the same size
- To actually reclaim Windows disk space:

```powershell
# Shut down WSL
wsl --shutdown

# Compact the VHDX (requires Hyper-V tools — included with Docker Desktop)
Optimize-VHD -Path "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx" -Mode Full

# If Optimize-VHD isn't available:
diskpart
> select vdisk file="C:\Users\jerb2\AppData\Local\Docker\wsl\disk\docker_data.vhdx"
> compact vdisk
> exit
```

---

## 9. WSL distribution updates breaking Docker

Docker Desktop installs its own WSL distros (`docker-desktop` + `docker-desktop-data`). If you run `wsl --update` from PowerShell, sometimes Docker breaks.

If Docker Desktop fails to start after wsl update:
1. Quit Docker Desktop
2. `wsl --shutdown`
3. Restart Docker Desktop
4. If still broken: Settings → Troubleshoot → Clean / Purge data (DESTRUCTIVE — wipes all images/containers/volumes)

---

## 10. Container time/timezone vs Windows

Containers default to UTC. Apps that need local timezone:

```dockerfile
# Alpine
RUN apk add --no-cache tzdata
ENV TZ=America/Argentina/Buenos_Aires

# Debian/Ubuntu
RUN apt-get update && apt-get install -y --no-install-recommends tzdata \
    && rm -rf /var/lib/apt/lists/*
ENV TZ=America/Argentina/Buenos_Aires
```

Or at runtime:
```bash
docker run -e TZ=America/Argentina/Buenos_Aires -v /etc/localtime:/etc/localtime:ro myapp
```

---

## 11. Symlinks across Windows ↔ container

Windows NTFS supports symlinks but they're not the same as Linux symlinks. When bind-mounted into a container:
- Linux symlinks created INSIDE the container survive container restarts (if on a volume)
- Windows symlinks bind-mounted in are often unreadable from container (permission issues)

Safer: avoid symlinks in mounted dirs; use compose `volumes` with subdirectory mounts instead.

---

## 12. `docker compose` from PowerShell — escape gotchas

```powershell
# WRONG — PowerShell interprets the $ before var name
docker compose run app sh -c "echo $DATABASE_URL"   # $DATABASE_URL is empty (PowerShell var)

# RIGHT — single quotes
docker compose run app sh -c 'echo $DATABASE_URL'   # $ passed literal to sh

# Or escape
docker compose run app sh -c "echo `$DATABASE_URL"  # backtick = PowerShell escape
```

---

## 13. Antivirus interference

Some AVs (Windows Defender, McAfee) scan everything in `\\wsl$\` and Docker volumes, causing dramatic slowdowns and occasional file lock errors.

**Add to exclusions**:
- `%USERPROFILE%\AppData\Local\Docker`
- `%USERPROFILE%\AppData\Roaming\Docker`
- `\\wsl$\` (or specific paths via UNC)
- Your project dirs if mounted

For Windows Defender:
```powershell
Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Docker"
Add-MpPreference -ExclusionPath "$env:APPDATA\Docker"
Add-MpPreference -ExclusionProcess "vmmem.exe"
Add-MpPreference -ExclusionProcess "com.docker.backend.exe"
```

---

## 14. Quick diagnostic — "Docker isn't working on Windows"

```powershell
# Is Docker Desktop running?
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue

# Is docker daemon responsive?
docker version
docker info

# Is WSL backend up?
wsl --status
wsl --list --verbose

# Restart Docker Desktop programmatically
Stop-Process -Name "Docker Desktop" -Force
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Reset to factory (NUCLEAR — wipes everything)
# Settings → Troubleshoot → Reset to factory defaults
```
