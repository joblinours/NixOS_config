#!/usr/bin/env bash
# Installation depuis l'ISO NixOS 26.05 (live, minimal ou graphique), en une ligne :
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/joblinours/NixOS_config/main/scripts/install.sh)" install nix-desktop
# (ou nix-desktop-vm, nix-laptop). Le script clone le dépôt GitHub dans /tmp/NixOS_config.
# Depuis un clone existant : sudo bash scripts/install.sh <host>
#
# ⚠ EFFACE les disques déclarés dans hosts/<host>/default.nix
#   (lucas.disk.device et lucas.disk.dataDevices) : ils sont affichés avant confirmation.
# Relançable : si les disques sont déjà montés sur /mnt (installation interrompue),
# propose de reprendre sans reformater.
set -euo pipefail
HOST="${1:?usage: install.sh <nix-desktop-vm|nix-desktop|nix-laptop>}"
REPO_URL="https://github.com/joblinours/NixOS_config.git"
export NIX_CONFIG="experimental-features = nix-command flakes"

# Lancé depuis un clone : on s'en sert ; sinon (curl) : on clone le dépôt
SELF="$(readlink -f "$0" 2>/dev/null || true)"
REPO="$(cd "$(dirname "$SELF")/.." 2>/dev/null && pwd || true)"
if [ ! -f "$REPO/flake.nix" ]; then
  REPO=/tmp/NixOS_config
  if [ -d "$REPO/.git" ]; then
    echo "→ Mise à jour de $REPO"
    nix run nixpkgs#git -- -C "$REPO" pull --ff-only
  else
    echo "→ Clonage de $REPO_URL dans $REPO"
    nix run nixpkgs#git -- clone "$REPO_URL" "$REPO"
  fi
  SELF="$REPO/scripts/install.sh"
fi

# Partitionner et installer exigent root : relance automatique via sudo
[ "$(id -u)" -eq 0 ] || exec sudo bash "$SELF" "$@"

# Machine physique : régénère la détection du matériel (sans les montages, gérés par disko)
if [ "$HOST" != nix-desktop-vm ] && [ -f "$REPO/hosts/$HOST/hardware-configuration.nix" ]; then
  read -rp "Régénérer hosts/$HOST/hardware-configuration.nix pour cette machine ? [O/n] " r
  if [ "${r:-O}" != n ]; then
    nixos-generate-config --no-filesystems --show-hardware-config > "$REPO/hosts/$HOST/hardware-configuration.nix"
    echo "✔ Matériel détecté (pense à committer ce fichier une fois installé)"
  fi
fi

# Laptop hybride : adresses PCI des GPU pour PRIME offload (hosts/<host>/prime.nix)
if [ -f "$REPO/hosts/$HOST/prime.nix" ]; then
  lspci_() { if command -v lspci >/dev/null; then lspci "$@"; else nix shell nixpkgs#pciutils -c lspci "$@"; fi; }
  # « 0000:01:00.0 » → « PCI:1:0:0 » (bus et device en décimal)
  busid() { local a="${1#*:}" b d; b="${a%%:*}"; d="${a#*:}"; printf 'PCI:%d:%d:%d' "$((16#$b))" "$((16#${d%%.*}))" "${d##*.}"; }
  NV="" INTEL="" AMD=""
  while read -r addr vendor; do
    case "$vendor" in
      10de) NV="$(busid "$addr")" ;;
      8086) INTEL="$(busid "$addr")" ;;
      1002) AMD="$(busid "$addr")" ;;
    esac
  done < <(lspci_ -Dn | awk '$2 ~ /^03(00|02|80):$/ { split($3, id, ":"); print $1, id[1] }')
  q() { [ -n "$1" ] && printf '"%s"' "$1" || printf 'null'; }
  if [ -n "$NV" ] && { [ -n "$INTEL" ] || [ -n "$AMD" ]; }; then
    cat > "$REPO/hosts/$HOST/prime.nix" <<NIX
# Adresses PCI des GPU pour PRIME offload (modules/nvidia.nix).
# Générées par scripts/install.sh (lspci) le $(date +%F) — à committer.
{
  lucas.nvidia.prime = {
    nvidiaBusId = $(q "$NV");
    intelBusId = $(q "$INTEL");
    amdgpuBusId = $(q "$AMD");
  };
}
NIX
    echo "✔ GPU détectés : NVIDIA $NV${INTEL:+, Intel $INTEL}${AMD:+, AMD $AMD} (hosts/$HOST/prime.nix)"
  else
    echo "⚠ GPU hybride non détecté (NVIDIA « $NV », iGPU « $INTEL$AMD ») : PRIME offload désactivé, voir hosts/$HOST/prime.nix"
  fi
fi

DISK="$(nix eval --raw "$REPO#nixosConfigurations.$HOST.config.lucas.disk.device")"
mapfile -t DATA < <(nix eval --json "$REPO#nixosConfigurations.$HOST.config.lucas.disk.dataDevices" | tr -d '[]"' | tr ',' '\n' | grep .)
echo "Host : $HOST"
echo "Disque système : $DISK"
[ "${#DATA[@]}" -gt 0 ] && printf 'Disque de données (/data) : %s\n' "${DATA[@]}"
echo
for d in "$DISK" "${DATA[@]}"; do
  [ -e "$d" ] || { echo "✘ Disque introuvable : $d (corrige hosts/$HOST/default.nix)" >&2; exit 1; }
  lsblk -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINTS "$d"
done

# Garde-fou : jamais depuis un système installé sur un disque cible
# (seuls des montages sous /mnt, laissés par une installation interrompue, sont admis)
MOUNTS=""
for d in "$DISK" "${DATA[@]}"; do
  m="$(lsblk -nro MOUNTPOINTS "$d" | grep . || true)"
  if echo "$m" | grep -v '^$' | grep -qv '^/mnt'; then
    echo "✘ $d est monté hors de /mnt :" >&2
    echo "$m" >&2
    echo "  Ce script doit tourner depuis l'ISO live (prompt nixos@nixos), pas depuis un système installé." >&2
    exit 1
  fi
  MOUNTS="$MOUNTS$m"
done

FORMAT=1
if mountpoint -q /mnt && [ -n "$MOUNTS" ]; then
  read -rp "Le disque est déjà monté sur /mnt (installation interrompue). Reprendre SANS reformater ? [O/n] " r
  [ "${r:-O}" = "n" ] || FORMAT=0
fi

if [ "$FORMAT" -eq 1 ]; then
  read -rp "Tout effacer sur les $(( ${#DATA[@]} + 1 )) disque(s) ci-dessus ? Taper OUI : " ans
  [ "$ans" = "OUI" ] || exit 1
  swapoff /mnt/.swapfile 2>/dev/null || true
  umount -R /mnt 2>/dev/null || true
  # 0. Effacement complet AVANT disko : les anciennes signatures (NTFS de Windows,
  #    ext4…) peuvent survivre sous les nouvelles partitions et faire échouer le
  #    montage (« NTFS signature is missing » sur la partition btrfs).
  for d in "$DISK" "${DATA[@]}"; do
    echo "→ Effacement de $d"
    for p in $(lsblk -nrpo NAME "$d" | tail -n +2); do wipefs -af "$p" >/dev/null || true; done
    wipefs -af "$d" >/dev/null
    blkdiscard -f "$d" 2>/dev/null || dd if=/dev/zero of="$d" bs=1M count=64 status=none
  done
  partprobe 2>/dev/null || true
  rm -f /run/blkid/blkid.tab* # cache blkid périmé
  udevadm settle
  # 1. Partitionnement + formatage + montage sur /mnt
  nix run github:nix-community/disko/latest -- --mode destroy,format,mount --yes-wipe-all-disks --flake "$REPO#$HOST"
fi

# Sur l'ISO live, / et /tmp sont en RAM : on construit et on swappe sur le disque
# pour ne pas saturer la mémoire (paquets non libres décompressés/construits localement)
mkdir -p /mnt/tmp
chmod 1777 /mnt/tmp
export TMPDIR=/mnt/tmp
if ! swapon --show=NAME --noheadings | grep -qx /mnt/.swapfile; then
  [ -f /mnt/.swapfile ] || btrfs filesystem mkswapfile --size 8g /mnt/.swapfile
  swapon /mnt/.swapfile
fi

# 2. Clé age perso (si les secrets existent) pour déchiffrer au 1er démarrage
if [ -f "$REPO/secrets/secrets.yaml" ] && [ ! -f /mnt/var/lib/sops-nix/key.txt ]; then
  read -rp "Chemin de ta clé age perso (keys.txt) sur cette machine : " K
  install -Dm600 "$K" /mnt/var/lib/sops-nix/key.txt
fi

# 3. Installation (pas de mot de passe root : sudo via l'utilisateur)
#    Parallélisme limité pour tenir dans la RAM d'une VM
nixos-install --flake "$REPO#$HOST" --no-root-passwd --max-jobs 2 --cores 2

# 4. Copie du dépôt (clone Git relié à GitHub) dans le home de l'utilisateur
U="$(nix eval --raw "$REPO#nixosConfigurations.$HOST.config.users.users" --apply 'u: builtins.head (builtins.filter (n: u.${n}.isNormalUser) (builtins.attrNames u))')"
mkdir -p "/mnt/home/$U"
rm -rf "/mnt/home/$U/nix-desktop-config"
cp -a "$REPO" "/mnt/home/$U/nix-desktop-config"
nixos-enter --root /mnt -c "chown -R $U:users /home/$U/nix-desktop-config"

# 5. Nettoyage : swap et dossier temporaires
swapoff /mnt/.swapfile && rm -f /mnt/.swapfile
rm -rf /mnt/tmp/*

echo "✔ Installé. Retire l'ISO puis : reboot"
