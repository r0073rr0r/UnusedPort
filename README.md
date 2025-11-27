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

### Option 1: Using APT Repository (Recommended)

Install from the official APT repository:

1. Add the repository and GPG key:

```bash
# Download and add the GPG key
curl -fsSL https://peace.dbase.in.rs/public.key | sudo gpg --dearmor -o /usr/share/keyrings/peace-repo.gpg

# Add the repository
echo "deb [signed-by=/usr/share/keyrings/peace-repo.gpg] https://peace.dbase.in.rs stable main" | sudo tee /etc/apt/sources.list.d/peace.list
```

1. Update package list and install:

```bash
sudo apt update
sudo apt install unused-port
```

1. Verify installation:

```bash
unused_port --help
```

### Option 2: Using Git (Full Repository)

1. Clone the repository:

```bash
git clone https://github.com/r0073rr0r/UnusedPort.git
cd UnusedPort
```

1. Make it executable:

```bash
chmod +x unused_port.sh
```

### Option 3: Using curl (Script Only)

Download only the script:

```bash
curl -o unused_port.sh https://raw.githubusercontent.com/r0073rr0r/UnusedPort/main/unused_port.sh
chmod +x unused_port.sh
```

### Option 4: Using wget (Script Only)

Download only the script:

```bash
wget https://raw.githubusercontent.com/r0073rr0r/UnusedPort/main/unused_port.sh
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

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

Velimir Majstorov

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [Contributing Guide](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).
