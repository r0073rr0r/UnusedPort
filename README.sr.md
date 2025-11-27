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

### Opcija 1: Koristeći APT Repozitorijum (Preporučeno)

Instaliraj iz zvaničnog APT repozitorijuma:

- Dodaj repozitorijum i GPG ključ:

```bash
# Preuzmi i dodaj GPG ključ
curl -fsSL https://peace.dbase.in.rs/public.key | sudo gpg --dearmor -o /usr/share/keyrings/peace-repo.gpg

# Dodaj repozitorijum
echo "deb [signed-by=/usr/share/keyrings/peace-repo.gpg] https://peace.dbase.in.rs stable main" | sudo tee /etc/apt/sources.list.d/peace.list
```

- Ažuriraj listu paketa i instaliraj:

```bash
sudo apt update
sudo apt install unused-port
```

- Proveri instalaciju:

```bash
unused_port --help
```

### Opcija 2: Koristeći Git (Ceo Repozitorijum)

1. Klonirajte repozitorijum:

```bash
git clone https://github.com/r0073rr0r/UnusedPort.git
cd UnusedPort
```

1. Dajte izvršne dozvole:

```bash
chmod +x unused_port.sh
```

### Opcija 3: Koristeći curl (Samo Skripta)

Preuzmite samo skriptu:

```bash
curl -o unused_port.sh https://raw.githubusercontent.com/r0073rr0r/UnusedPort/main/unused_port.sh
chmod +x unused_port.sh
```

### Opcija 4: Koristeći wget (Samo Skripta)

Preuzmite samo skriptu:

```bash
wget https://raw.githubusercontent.com/r0073rr0r/UnusedPort/main/unused_port.sh
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

Ovaj projekat je licenciran pod MIT licencom - pogledajte [LICENSE](LICENSE) fajl za detalje.

## 👤 Autor

Velimir Majstorov

## 🤝 Kontribucije

Kontribucije, issue-i i feature request-ovi su dobrodošli! Slobodno pogledajte [Contributing Guide](CONTRIBUTING.md) i [Code of Conduct](CODE_OF_CONDUCT.md).
