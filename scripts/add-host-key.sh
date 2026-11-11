#!/usr/bin/env bash
# Après le 1er démarrage d'un host : ajoute sa clé (dérivée de sa clé SSH) à
# .sops.yaml et rechiffre les secrets. Ensuite la copie de la clé perso dans
# /var/lib/sops-nix/key.txt n'est plus indispensable.
#   bash scripts/add-host-key.sh            (sur le host lui-même)
#   bash scripts/add-host-key.sh 192.168.1.201   (à distance)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
if [ -n "${1:-}" ]; then
  HOSTKEY="$(ssh-keyscan -t ed25519 "$1" 2>/dev/null | ssh-to-age)"
else
  HOSTKEY="$(ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)"
fi
grep -q "$HOSTKEY" .sops.yaml && { echo "Clé déjà présente."; exit 0; }
sed -i "s|^  - &lucas \(.*\)$|  - \&lucas \1\n  - $HOSTKEY|" .sops.yaml
sed -i "s|^          - \*lucas$|          - *lucas\n          - $HOSTKEY|" .sops.yaml
sops updatekeys -y secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
echo "✔ Clé de l'host ajoutée : $HOSTKEY"
