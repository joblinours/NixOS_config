#!/usr/bin/env bash
# Sauvegarde de la Kali (tour) vers le disque USB Samsung T7 Shield, AVANT
# l'installation de NixOS (qui efface le Lexar Kali, le Lexar Windows et le Kingston).
#
# Dépôt restic chiffré : /mnt/2To_lucas/restic-kali
# Mot de passe demandé à la création puis à chaque étape : NOTE-LE dans Bitwarden,
# sans lui la sauvegarde est illisible.
#
#   sudo apt install restic        (une fois)
#   bash sauvegarde-kali.sh
#
# Relançable sans risque : restic ne réenvoie que ce qui a changé.
set -euo pipefail

T7="/mnt/2To_lucas"
WIN="/run/media/joblinours/01DA9430FCCDAE90"
export RESTIC_REPOSITORY="$T7/restic-kali"
H="$HOME"

titre() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
oui() { read -rp "$1 [o/N] " r; [ "${r,,}" = o ]; }

command -v restic >/dev/null || { echo "Installe restic d'abord : sudo apt install restic" >&2; exit 1; }
mountpoint -q "$T7" || { echo "Le T7 Shield n'est pas monté sur $T7" >&2; exit 1; }
df -h "$T7" | tail -1

# Mot de passe saisi une seule fois pour tout le script (jamais écrit sur disque)
read -rsp "Mot de passe du dépôt restic : " RESTIC_PASSWORD; echo
export RESTIC_PASSWORD

if [ ! -f "$RESTIC_REPOSITORY/config" ]; then
  titre "Création du dépôt $RESTIC_REPOSITORY"
  read -rsp "Confirme le mot de passe : " p2; echo
  [ "$p2" = "$RESTIC_PASSWORD" ] || { echo "Mots de passe différents" >&2; exit 1; }
  restic init
fi

# ── 1. Inventaire (pour ne rien oublier en recréant l'environnement) ──
titre "Inventaire"
INV="$H/inventaire-kali"
mkdir -p "$INV"
apt-mark showmanual > "$INV/paquets-apt-manuels.txt" 2>/dev/null || true
docker volume ls > "$INV/docker-volumes.txt" 2>/dev/null || true
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' > "$INV/docker-conteneurs.txt" 2>/dev/null || true
crontab -l > "$INV/crontab.txt" 2>/dev/null || true
code --list-extensions > "$INV/vscode-extensions.txt" 2>/dev/null || true
ls /etc/NetworkManager/system-connections > "$INV/connexions-reseau.txt" 2>/dev/null || true
echo "→ $INV (inclus dans la sauvegarde du home)"

# ── 2. Home (sans caches ni fichiers régénérables) ────────────────────
titre "Home ($H)"
restic backup "$H" --tag kali-home --exclude-caches \
  --exclude "$H/VirtualBox VMs" \
  --exclude "$H/.cache" \
  --exclude "$H/.npm" \
  --exclude "$H/.rustup" \
  --exclude "$H/.cargo/registry" \
  --exclude "$H/.local/share/Trash" \
  --exclude "$H/.local/share/Steam" \
  --exclude "$H/.vscode/extensions" \
  --exclude "$H/.vscode-oss/extensions" \
  --exclude "$H/.var/app/*/cache" \
  --exclude "node_modules" \
  --exclude "__pycache__" \
  --exclude "$H/homelab/nixos/nix-desktop-config/result" \
  --exclude "$H/Downloads/*.iso"

# Contrôle : les éléments indispensables sont-ils bien dans la sauvegarde ?
titre "Contrôle des éléments indispensables"
for p in homelab Script Git Downloads/leak \
  .config/opendeck .local/share/opendeck \
  .claude .claude.json .config/Claude/claude_desktop_config.json \
  .config/Code/User .ssh .gnupg inventaire-kali; do
  [ -e "$H/$p" ] || { printf '  - %s (absent de la Kali)\n' "$p"; continue; }
  if restic ls latest --tag kali-home "$H/$p" 2>/dev/null | grep -q .; then
    printf '  \033[32m✔\033[0m %s\n' "$p"
  else
    printf '  \033[31m✘ %s MANQUANT dans la sauvegarde\033[0m\n' "$p"
  fi
done

# ── 3. VMs VirtualBox : au choix ──────────────────────────────────────
titre "VMs VirtualBox"
for vm in "$H/VirtualBox VMs"/*/; do
  [ -d "$vm" ] || continue
  taille="$(du -sh "$vm" | cut -f1)"
  if oui "Sauvegarder la VM « $(basename "$vm") » ($taille) ?"; then
    restic backup "$vm" --tag vm
  fi
done

# ── 4. Windows (Users/jobli) : au choix ───────────────────────────────
titre "Données Windows"
if mountpoint -q "$WIN"; then
  U="$WIN/Users/jobli"
  essentiels=()
  for d in Documents Desktop Pictures Music Videos Zotero; do
    [ -e "$U/$d" ] && essentiels+=("$U/$d")
  done
  if [ "${#essentiels[@]}" -gt 0 ]; then
    echo "Essentiels : ${essentiels[*]##*/}"
    restic backup "${essentiels[@]}" --tag windows
  fi
  for d in Downloads "VirtualBox VMs"; do
    [ -e "$U/$d" ] || continue
    taille="$(du -sh "$U/$d" 2>/dev/null | cut -f1)"
    oui "Sauvegarder Windows « $d » ($taille) ?" && restic backup "$U/$d" --tag windows
  done
else
  echo "⚠ Partition Windows non montée ($WIN) : ouvre-la dans le gestionnaire de fichiers puis relance."
fi

# ── 5. Modèles Ollama (Kingston) ──────────────────────────────────────
titre "Modèles Ollama"
if [ -d /mnt/ollama-models ] && oui "Sauvegarder /mnt/ollama-models ($(du -sh /mnt/ollama-models 2>/dev/null | cut -f1)) ? (sinon : à retélécharger)"; then
  restic backup /mnt/ollama-models --tag ollama
fi

# ── 6. Volumes Docker (bases de données des projets, etc.) ────────────
titre "Volumes Docker"
if oui "Sauvegarder les volumes Docker ? (les conteneurs seront arrêtés pendant la copie)"; then
  mapfile -t actifs < <(docker ps -q)
  [ "${#actifs[@]}" -gt 0 ] && docker stop "${actifs[@]}" >/dev/null
  sudo --preserve-env=RESTIC_REPOSITORY,RESTIC_PASSWORD "$(command -v restic)" backup /var/lib/docker/volumes --tag docker
  [ "${#actifs[@]}" -gt 0 ] && docker start "${actifs[@]}" >/dev/null
fi

# ── 7. Vérification ───────────────────────────────────────────────────
titre "Vérification de l'intégrité"
restic check
restic snapshots
restic stats --mode raw-data
echo
echo "✔ Sauvegarde terminée sur le T7 Shield. Garde le mot de passe en lieu sûr."
