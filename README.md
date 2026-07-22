# work-env

A bootstrap script that prepares a self-contained, portable workspace directory.

The single entry point `init-linux.sh`:

- creates a standardized workspace directory layout
- downloads and builds/installs portable versions of the most commonly used tools (psql, Java, Perl, pgBadger, ASH-Viewer, JDBC driver, psql-dba-tools)
- generates a sourced profile that exposes convenient aliases, environment variables and helpers
- registers shell aliases so the workspace can be activated with a single command

All software is installed **inside** the workspace directory (`~/workspace-<ORG_NAME>/soft/...`), so nothing pollutes the system and the whole workspace can be relocated or removed by moving/deleting one folder.

---

## Repository contents

| File | Purpose |
|------|---------|
| `init-linux.sh` | Main installer script. Creates the workspace, downloads and sets up all tools. |
| `template_profile` | Template for the generated `settings/profile`. Sourced to activate the workspace. |
| `template_psqlrc` | Template for the generated `settings/psqlrc` with psql prompt/timing settings. |
| `example.env` | Template for connection environment files placed in `inventory/`. |

---

## Quick start

```bash
# 1. Review / adjust config values at the top of the script
#    ORG_NAME, PROJECT_ROOT_DIR, DOWNLOADS_DIR, DEFAULT_PGUSER
./init-linux.sh

# 2. Restart your shell (or reload ~/.bashrc), then activate the workspace
env<ORG_NAME>            # e.g. envmycompany
# or, skip the credentials prompt:
env<ORG_NAME>skipcreds   # e.g. envmycompanyskipcreds
```

Requirements:

- `bash`
- Internet access (the script checks connectivity to its download hosts before software setup).
- Build tools for `psql`: `gcc`, `make`, `libreadline-dev`.
- `git` (for `psql-dba-tools`).
- `wget` or `curl` (for downloads).

---

## Resulting workspace layout

After running `init-linux.sh`, the workspace (default `~/workspace-<ORG_NAME>/`) looks like this:

```
workspace-<ORG_NAME>/
├── cert/                # SSL/TLS certificates, CA bundles
├── hr/                  # HR-related documents
├── inventory/           # *.env files with DB/SSH connection definitions
│   └── example.env      # Template copied here by the installer
├── keys/
│   ├── private/         # SSH/GPG private keys
│   └── public/          # SSH/GPG public keys
├── learning/            # Tutorials, docs, courses
├── notes/               # Cheatsheets and quick-reference materials
├── projects/            # Per-project files and documents
├── secrets/             # Passwords and other sensitive credentials
├── settings/
│   ├── profile          # Generated - source it to activate the workspace
│   └── psqlrc           # Generated - psql configuration
├── soft/                # Portable software installed by the script
│   ├── sh/              # Shell scripts
│   ├── sql/             # SQL scripts
│   ├── ash-viewer/      # ASH-Viewer (GUI tool)
│   ├── java/            # Portable JDK 11
│   │   └── jdbc/        # PostgreSQL JDBC driver
│   ├── keepass2/        # KeePass 2
│   ├── putty/           # PuTTY
│   ├── perl/            # Portable Perl 5.40
│   ├── pgbadger/        # pgBadger
│   ├── psql/            # Portable psql 16 client (compiled from source)
│   └── psql-dba-tools/  # DBA helper scripts (cloned from GitHub)
├── tmp/                 # Temporary files
└── downloads -> ~/downloads   # Symlink to your downloads directory
```

Each first-level directory contains a `README.md` describing its purpose.

---

## Activating the workspace

The installer appends two aliases to `~/.bashrc`:

```bash
alias env<ORG_NAME>="source ~/workspace-<ORG_NAME>/settings/profile"
alias env<ORG_NAME>skipcreds="SKIP_CREDS=yes source ~/workspace-<ORG_NAME>/settings/profile"
```

Sourcing the profile will:

1. **Optionally** ask for `PGUSER`/`PGPASSWORD` (skipped with the `skipcreds` variant, or if `SKIP_CREDS=yes` is already set).
2. Set a custom shell prompt (`<ORG_NAME> user@host:cwd$`).
3. Export environment variables (`WORKSPACE`, `ORG_NAME`, `DEFAULT_PGUSER`, `JAVA_HOME`, `ASHV_HOME`, `PSQLRC`, etc.).
4. Define navigation aliases for every workspace subdirectory, prefixed with `cd` (e.g. `cdinventory`, `cdsoft`, `cdkeys`).
5. Define tool aliases so the portable versions are used:
   - `psql`, `perl`, `pgbadger`, `java` (as aliases pointing into `soft/`)
   - `ashv` (launches ASH-Viewer in the background)
6. Source every `*.env` file found under `inventory/` so database/SSH connection variables become available.
