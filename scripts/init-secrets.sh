#!/usr/bin/env bash
# Crée la clé age perso (si absente), remplit .sops.yaml et chiffre
# secrets/secrets.yaml avec le hash du mot de passe de l'utilisateur.
# À lancer dans `nix develop` (fournit sops, age, ssh-to-age, mkpasswd).
#   bash scripts/init-secrets.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
if [ ! -f "$KEY" ]; then
  mkdir -p "$(dirname "$KEY")"
  age-keygen -o "$KEY"
  chmod 600 "$KEY"
  echo "→ Clé age créée : $KEY  (SAUVEGARDE-LA dans Bitwarden : sans elle, secrets illisibles)"
fi
PUB="$(age-keygen -y "$KEY")"
sed -i "s|AGE_CLE_PERSO_A_REMPLACER|$PUB|" .sops.yaml
echo "→ Clé publique perso : $PUB"

if [ -f secrets/secrets.yaml ]; then
  echo "secrets/secrets.yaml existe déjà : édite-le avec  sops secrets/secrets.yaml"
  exit 0
fi

HASH="$(nix run nixpkgs#mkpasswd -- -m yescrypt)"
umask 077
printf 'user-password: %s\n' "$HASH" > secrets/secrets.yaml
sops --encrypt --in-place secrets/secrets.yaml
git add .sops.yaml secrets/secrets.yaml
echo "✔ secrets/secrets.yaml chiffré et ajouté à Git."
