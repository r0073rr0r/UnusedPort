# 🔍 Unused Port Checker

A script for checking and removing unused ports from firewall rules (UFW or iptables).

## 📋 Description

This bash script checks which ports from firewall rules are currently not in use. It can:

- ✅ Check all ports from firewall rules
- ✅ Check a specific port
- ✅ Display unused ports
- ✅ Remove unused ports from firewall (with backup option)
- ✅ Restore removed rules from backup

## 📦 Requirements

- 🐧 Linux operating system
- 💻 Bash shell
- 🔥 UFW or iptables firewall
- 🔌 `ss` or `lsof` for port checking
- 🔐 Root privileges for removing rules (iptables requires root for reading rules too)

## 🚀 Installation

1. Clone or download the script:

```bash
git clone <repository-url>
cd UnusedPort
```

1. Make it executable:

```bash
chmod +x unused_port.sh
```

## 💡 Usage

### Basic Commands

```bash
# Check all UFW ports (uses ss by default)
./unused_port.sh

# Check a specific port
./unused_port.sh -p 8080

# Check iptables ports
./unused_port.sh --iptables

# Show what would be removed (dry-run)
./unused_port.sh --dry-run

# Remove unused ports (with backup and confirmation)
sudo ./unused_port.sh --remove

# Remove unused ports without confirmation
sudo ./unused_port.sh --remove --yes
```

### Options

| Option | Description |
|--------|-------------|
| `-p, --port PORT` | Check a specific port |
| `-r, --remove` | Remove unused ports from firewall |
| `-d, --dry-run` | Show what would be removed without actually removing |
| `-y, --yes` | Skip confirmation prompt (use with --remove) |
| `--force` | Skip backup creation when removing (not recommended) |
| `--restore [FILE]` | Restore firewall rules from the last backup (or from FILE if provided) |
| `--restore-from FILE` | Restore firewall rules from a specific backup file |
| `--list-backups` | List all available backup files |
| `--show-last-backup` | Show the path to the last backup file |
| `--ss` | Use 'ss' for port checking (default) |
| `--lsof` | Use 'lsof' for port checking |
| `--ufw` | Use UFW firewall (default) |
| `--iptables` | Use iptables firewall |
| `-h, --help` | Show help message |

### Examples

```bash
# Check port 8080
./unused_port.sh -p 8080

# Check iptables ports using lsof
./unused_port.sh --iptables --lsof

# Preview unused ports
./unused_port.sh --dry-run

# Remove unused ports with backup
sudo ./unused_port.sh --remove

# Remove without confirmation
sudo ./unused_port.sh --remove --yes

# Restore rules from last backup
sudo ./unused_port.sh --restore

# Restore rules from specific backup file
sudo ./unused_port.sh --restore-from firewall_backup_ufw_20240101_120000.txt

# List all backup files
./unused_port.sh --list-backups
```

## 💾 Backup and Restore

The script automatically creates a backup before removing rules (unless `--force` is used). Backup files are stored in:

- `~/.unused_port_backups/` (if possible)
- `/tmp/unused_port_backups/` (fallback)

Each backup file has the format: `firewall_backup_<tool>_<date>_<time>.txt`

The script also creates a symlink to the latest backup for easier restoration.

### Restore Commands

```bash
# Restore from last backup
sudo ./unused_port.sh --restore

# Restore from specific file
sudo ./unused_port.sh --restore-from firewall_backup_ufw_20240101_120000.txt

# List all backups
./unused_port.sh --list-backups

# Show last backup
./unused_port.sh --show-last-backup
```

## 🪟 Testing on Windows

Since this is a Linux script, you can test it on Windows in several ways:

### Option 1: WSL (Windows Subsystem for Linux)

1. Install WSL:

```powershell
wsl --install
```

1. Run WSL and navigate to the project:

```bash
cd /mnt/d/Projects/UnusedPort
./unused_port.sh --help
```

### Option 2: Docker

1. Install Docker Desktop for Windows
1. Run a Linux container:

```bash
docker run -it --rm -v /d/Projects/UnusedPort:/workspace ubuntu:latest bash
```

1. Inside the container:

```bash
apt-get update
apt-get install -y bash ufw iptables iproute2 lsof
cd /workspace
chmod +x unused_port.sh
./unused_port.sh --help
```

### Option 3: Virtual Machine

Use VirtualBox or VMware with a Linux distribution.

## 🧪 Testing

To run tests, see `tests/README.md` or run:

```bash
# In Linux environment (WSL, Docker, or Linux VM)
cd tests
./run_tests.sh
```

## ⚠️ Security

⚠️ **WARNING**: Removing firewall rules can affect system security and connectivity. Always:

- 📝 Review what will be removed before confirming
- 🔍 Use `--dry-run` option first
- 🚫 Don't use `--force` unless you're sure
- 💾 Keep backup files in a safe place

## 🛠️ Support

- 🔥 **UFW**: Requires UFW firewall
- 🔐 **iptables**: Requires root privileges for reading and writing rules
- ⚡ **ss**: Faster than lsof, recommended
- 🔌 **lsof**: Alternative if ss is not available

## 📄 License

[Add your license here]

## 👤 Author

[Your name]

## 🤝 Contributing

Pull requests and issues are welcome!
