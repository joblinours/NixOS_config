#!/usr/bin/env bash
# Vérifie que l'installation fonctionne (sur la VM ou la tour).
#   bash ~/nix-desktop-config/scripts/test.sh          # complet
#   bash ~/nix-desktop-config/scripts/test.sh --quick  # sans docker run / flake check
set -u
QUICK=0; [ "${1:-}" = "--quick" ] && QUICK=1
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
WANTUSER="$(sed -n 's/^ *username = "\(.*\)";.*/\1/p' "$REPO/flake.nix" | head -n1)"

PASS=0; FAIL=0; WARN=0
ok()  { printf '  \033[32m✔\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
ko()  { printf '  \033[31m✘\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
wn()  { printf '  \033[33m!\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
sec() { printf '\n\033[1m%s\033[0m\n' "$*"; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }

sec "1. Système"
check "NixOS 26.05"               grep -q '^26\.05' /run/current-system/nixos-version
check "utilisateur = $WANTUSER"   test "$(whoami)" = "$WANTUSER"
check "hostname nix-desktop*"     sh -c 'hostname | grep -q ^nix-desktop'
state="$(systemctl is-system-running 2>/dev/null || true)"
case "$state" in
  running)  ok "systemd : running" ;;
  degraded) wn "systemd : degraded → systemctl --failed" ;;
  *)        ko "systemd : $state" ;;
esac
check "racine en btrfs"           sh -c 'findmnt -no FSTYPE / | grep -q btrfs'
check "zram actif"                sh -c 'swapon --show | grep -q zram'

sec "2. Réseau"
case "$(hostname)" in nix-desktop) IP=192.168.1.200 ;; *) IP=192.168.1.201 ;; esac
check "IP $IP/23"                 sh -c "ip -4 -o addr | grep -q '$IP/23'"
check "passerelle 192.168.0.1"    sh -c 'ip route | grep -q "default via 192.168.0.1"'
check "DNS via AdGuard 192.168.1.3" sh -c 'dig +short +time=2 @192.168.1.3 nixos.org | grep -q .'
check "DNS (nixos.org)"           getent hosts nixos.org
check "sshd actif"                systemctl is-active --quiet sshd
check "SSH : mot de passe refusé" grep -qi '^PasswordAuthentication no' /etc/ssh/sshd_config

sec "3. Bureau"
check "écran de connexion (SDDM)" systemctl is-active --quiet display-manager
check "session Plasma dispo"      test -e /run/current-system/sw/share/wayland-sessions/plasma.desktop
check "pipewire (user)"           systemctl --user is-active --quiet pipewire
check "easyeffects (user)"        systemctl --user is-active --quiet easyeffects
check "police MesloLGS Nerd Font" sh -c 'fc-list | grep -q "MesloLGS Nerd Font"'

sec "4. Shell"
check "shell par défaut = zsh"    sh -c 'getent passwd "$(whoami)" | grep -q zsh'
check "~/.zshrc géré par Nix"     sh -c 'readlink -f ~/.zshrc | grep -q ^/nix/store'
check "~/.p10k.zsh présent"       test -e ~/.p10k.zsh
check "Oh My Zsh chargé"          sh -c 'grep -q "oh-my-zsh.sh" ~/.zshrc'
check "police Awesome Terminal"   sh -c 'fc-list | grep -qi fontawesome'
if grep -q 'dataDevices = \[$' "$REPO/hosts/$(hostname)/default.nix" 2>/dev/null; then
  check "/data monté (disques de données)" mountpoint -q /data
fi
check "config ghostty"            test -e ~/.config/ghostty/config

sec "5. Outils"
for c in ghostty nano code claude claude-desktop obsidian VirtualBox docker lazydocker lazygit brave firefox discord \
         remmina sshm python3 uv burpsuite wireshark tshark nmap hashcat john vulnx searchsploit qFlipper lm-studio \
         anydesk bitwarden bw clamscan gdu dust baobab easyeffects mpv celluloid loupe papers gcc clang make cmake gdb \
         valgrind rustup node pnpm go java ghidra obs steam Telegram signal-desktop \
         fls autopsy yara capa floss die upx readpe triage flatpak \
         plasmashell krunner kwin_wayland dolphin mousepad spectacle solaar vicinae tiling-toggle \
         linux-wallpaperengine autojump catimg xdg-open fastfetch dig nslookup traceroute mtr whois iperf3 \
         http xh hurl wg openvpn tailscale gamemoderun gamescope mangohud protonup-qt lutris heroic \
         photocraft pdfcraft wordcraft gridcraft cadcraft; do
  if command -v "$c" >/dev/null 2>&1; then ok "$c"
  elif [ "$c" = VirtualBox ] && ! grep -q 'vbox.enable = true' "$REPO/hosts/$(hostname)/default.nix" 2>/dev/null; then wn "$c (désactivé sur cet host)"
  else ko "$c"; fi
done

sec "6. Services"
for s in docker clamav-daemon clamav-freshclam.timer NetworkManager tailscaled lucas-auto-upgrade.timer; do
  check "$s" systemctl is-active --quiet "$s"
done
if [ -n "$(ls /sys/class/bluetooth 2>/dev/null)" ]; then
  check "bluetooth" systemctl is-active --quiet bluetooth
else
  wn "bluetooth : aucun adaptateur (normal dans la VM)"
fi
check "groupe wireshark"          sh -c 'id -nG | grep -qw wireshark'
check "groupe docker"             sh -c 'id -nG | grep -qw docker'
check "groupe kvm (Cowork)"       sh -c 'id -nG | grep -qw kvm'
check "module vhost_vsock"        sh -c 'lsmod | grep -q vhost_vsock'
check "flatpak-managed-install OK" sh -c '! systemctl is-failed --quiet flatpak-managed-install.service'

sec "7. Flatpak"
for a in me.amankhanna.opendeck; do
  check "$a" sh -c "flatpak list --app --columns=application | grep -qx $a"
done

sec "8. Secrets (sops)"
if [ -f "$REPO/secrets/secrets.yaml" ]; then
  check "secret user-password déchiffré" sudo -n test -s /run/secrets-for-users/user-password
else
  wn "pas de secrets/secrets.yaml (mot de passe initial changeme)"
fi

if [ $QUICK -eq 0 ]; then
  sec "9. Tests longs"
  check "docker run hello-world"  docker run --rm hello-world
  check "nix flake check"         nix flake check "$REPO" --no-build
  if command -v nvidia-smi >/dev/null; then
    check "nvidia-smi"            nvidia-smi
    check "GPU dans Docker (CDI)" docker run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi
  fi
fi

printf '\n\033[1mRésultat : %d OK, %d échec(s), %d avertissement(s)\033[0m\n' "$PASS" "$FAIL" "$WARN"
[ "$FAIL" -eq 0 ]
