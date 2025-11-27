# 🔍 Unused Port Checker

Skripta za proveru i uklanjanje neiskorišćenih portova iz firewall pravila (UFW ili iptables).

## 📋 Opis

Ova bash skripta proverava koje portove iz firewall pravila trenutno nisu u upotrebi. Može da:

- ✅ Proveri sve portove iz firewall pravila
- ✅ Proveri određeni port
- ✅ Prikaže neiskorišćene portove
- ✅ Ukloni neiskorišćene portove iz firewall-a (sa opcijom backup-a)
- ✅ Vrati uklonjena pravila iz backup-a

## 📦 Zahtevi

- 🐧 Linux operativni sistem
- 💻 Bash shell
- 🔥 UFW ili iptables firewall
- 🔌 `ss` ili `lsof` za proveru portova
- 🔐 Root privilegije za uklanjanje pravila (iptables zahteva root i za čitanje pravila)

## 🚀 Instalacija

1. Klonirajte ili preuzmite skriptu:

```bash
git clone <repository-url>
cd UnusedPort
```

1. Dajte izvršne dozvole:

```bash
chmod +x unused_port.sh
```

## 💡 Korišćenje

### Osnovne komande

```bash
# Proveri sve UFW portove (koristi ss po defaultu)
./unused_port.sh

# Proveri određeni port
./unused_port.sh -p 8080

# Proveri iptables portove
./unused_port.sh --iptables

# Prikaži šta bi bilo uklonjeno (dry-run)
./unused_port.sh --dry-run

# Ukloni neiskorišćene portove (sa backup-om i potvrdom)
sudo ./unused_port.sh --remove

# Ukloni neiskorišćene portove bez potvrde
sudo ./unused_port.sh --remove --yes
```

### Opcije

| Opcija | Opis |
|--------|------|
| `-p, --port PORT` | Proveri određeni port |
| `-r, --remove` | Ukloni neiskorišćene portove iz firewall-a |
| `-d, --dry-run` | Prikaži šta bi bilo uklonjeno bez stvarnog uklanjanja |
| `-y, --yes` | Preskoči potvrdu (koristi sa --remove) |
| `--force` | Preskoči kreiranje backup-a (nije preporučeno) |
| `--restore [FILE]` | Vrati firewall pravila iz poslednjeg backup-a (ili iz FILE ako je naveden) |
| `--restore-from FILE` | Vrati firewall pravila iz određenog backup fajla |
| `--list-backups` | Lista svih dostupnih backup fajlova |
| `--show-last-backup` | Prikaži putanju do poslednjeg backup fajla |
| `--ss` | Koristi 'ss' za proveru portova (default) |
| `--lsof` | Koristi 'lsof' za proveru portova |
| `--ufw` | Koristi UFW firewall (default) |
| `--iptables` | Koristi iptables firewall |
| `-h, --help` | Prikaži help poruku |

### Primeri

```bash
# Proveri port 8080
./unused_port.sh -p 8080

# Proveri iptables portove koristeći lsof
./unused_port.sh --iptables --lsof

# Prikaži preview neiskorišćenih portova
./unused_port.sh --dry-run

# Ukloni neiskorišćene portove sa backup-om
sudo ./unused_port.sh --remove

# Ukloni bez potvrde
sudo ./unused_port.sh --remove --yes

# Vrati pravila iz poslednjeg backup-a
sudo ./unused_port.sh --restore

# Vrati pravila iz određenog backup fajla
sudo ./unused_port.sh --restore-from firewall_backup_ufw_20240101_120000.txt

# Lista svih backup fajlova
./unused_port.sh --list-backups
```

## 💾 Backup i Restore

Skripta automatski kreira backup pre uklanjanja pravila (osim ako se koristi `--force`). Backup fajlovi se čuvaju u:

- `~/.unused_port_backups/` (ako je moguće)
- `/tmp/unused_port_backups/` (fallback)

Svaki backup fajl ima format: `firewall_backup_<tool>_<datum>_<vreme>.txt`

Skripta takođe kreira symlink na poslednji backup za lakše vraćanje.

### Restore komande

```bash
# Vrati iz poslednjeg backup-a
sudo ./unused_port.sh --restore

# Vrati iz određenog fajla
sudo ./unused_port.sh --restore-from firewall_backup_ufw_20240101_120000.txt

# Lista svih backup-ova
./unused_port.sh --list-backups

# Prikaži poslednji backup
./unused_port.sh --show-last-backup
```

## 🪟 Testiranje na Windows-u

Pošto je ovo Linux skripta, možete je testirati na Windows-u na nekoliko načina:

### Opcija 1: WSL (Windows Subsystem for Linux)

1. Instalirajte WSL:

```powershell
wsl --install
```

1. Pokrenite WSL i navigirajte do projekta:

```bash
cd /mnt/d/Projects/UnusedPort
./unused_port.sh --help
```

### Opcija 2: Docker

1. Instalirajte Docker Desktop za Windows
1. Pokrenite Linux kontejner:

```bash
docker run -it --rm -v /d/Projects/UnusedPort:/workspace ubuntu:latest bash
```

1. U kontejneru:

```bash
apt-get update
apt-get install -y bash ufw iptables iproute2 lsof
cd /workspace
chmod +x unused_port.sh
./unused_port.sh --help
```

### Opcija 3: Virtualna mašina

Koristite VirtualBox ili VMware sa Linux distribucijom.

## 🧪 Testiranje

Za pokretanje testova, pogledajte `tests/README.md` ili pokrenite:

```bash
# U Linux okruženju (WSL, Docker, ili Linux VM)
cd tests
./run_tests.sh
```

## ⚠️ Sigurnost

⚠️ **UPOZORENJE**: Uklanjanje firewall pravila može uticati na sigurnost i konektivnost sistema. Uvek:

- 📝 Pregledajte šta će biti uklonjeno pre potvrde
- 🔍 Koristite `--dry-run` opciju prvo
- 🚫 Ne koristite `--force` osim ako niste sigurni
- 💾 Čuvajte backup fajlove na sigurnom mestu

## 🛠️ Podrška

- 🔥 **UFW**: Zahteva UFW firewall
- 🔐 **iptables**: Zahteva root privilegije za čitanje i pisanje pravila
- ⚡ **ss**: Brži od lsof, preporučeno
- 🔌 **lsof**: Alternativa ako ss nije dostupan

## 📄 Licenca

[Ovde dodajte vašu licencu]

## 👤 Autor

[Vaše ime]

## 🤝 Kontribucije

Dobrodošli su pull request-ovi i issue-i!
