#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq
# Génère un ~/.ssh/config (lu par ssh, lazyssh / lssh et sshm) depuis la CMDB NetBox.
# Prend les VM et équipements actifs qui ont une IP primaire.
#
# Usage :
#   export NETBOX_URL=http://<ip-netbox>:<port>
#   export NETBOX_TOKEN=<token API en lecture>
#   ./scripts/netbox-ssh-config.sh                  # affiche le résultat
#   ./scripts/netbox-ssh-config.sh > ~/.ssh/config  # l'écrit (faire une copie avant)
#
# Champs personnalisés NetBox facultatifs (sur VM et Device) :
#   ssh_user (texte), ssh_port (entier). Sinon : $SSH_DEFAULT_USER (joblinours) et 22.
# Clé : $SSH_IDENTITY (~/.ssh/id_ed25519 par défaut).
set -euo pipefail

: "${NETBOX_URL:?Définir NETBOX_URL}"
: "${NETBOX_TOKEN:?Définir NETBOX_TOKEN}"
DEFAULT_USER="${SSH_DEFAULT_USER:-joblinours}"
IDENTITY="${SSH_IDENTITY:-~/.ssh/id_ed25519}"

# Jetons v2 (NetBox ≥ 4.5, préfixe nbt_) : Bearer ; anciens jetons : Token
if [[ "$NETBOX_TOKEN" == nbt_* ]]; then AUTH="Bearer $NETBOX_TOKEN"; else AUTH="Token $NETBOX_TOKEN"; fi

api() {
  curl -fsS -H "Authorization: $AUTH" -H "Accept: application/json" \
    "${NETBOX_URL%/}/api/$1"
}

objs=$(
  {
    api "virtualization/virtual-machines/?status=active&has_primary_ip=true&limit=0" | jq -c '.results[] | . + {kind:"VM"}'
    api "dcim/devices/?status=active&has_primary_ip=true&limit=0" | jq -c '.results[] | . + {kind:"Device"}'
  }
)

echo "# Généré depuis NetBox (${NETBOX_URL}) le $(date '+%F %T') — ne pas éditer à la main"
echo "# Régénérer : scripts/netbox-ssh-config.sh > ~/.ssh/config"
echo
jq -r --arg user "$DEFAULT_USER" -s '
  sort_by(.name | ascii_downcase)[]
  | "# \(.kind) — \(.role.name // .site.name // .cluster.name // "")" ,
    "Host \(.name | ascii_downcase | gsub("[^a-z0-9._-]"; "-"))",
    "  HostName \(.primary_ip.address | split("/")[0])",
    "  User \(.custom_fields.ssh_user // $user)",
    "  Port \(.custom_fields.ssh_port // 22)",
    ""
' <<<"$objs"
# Valeurs par défaut EN DERNIER : ssh garde la première valeur trouvée pour chaque option
echo "Host *"
echo "  IdentityFile $IDENTITY"
echo "  IdentitiesOnly yes"
echo "  ServerAliveInterval 30"
