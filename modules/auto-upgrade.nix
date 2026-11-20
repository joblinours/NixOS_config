# Mise à jour automatique hebdomadaire (paquets, Oh My Zsh, plugins…).
# 1. met à jour flake.lock dans ~/nix-desktop-config (en tant qu'utilisateur) ;
# 2. construit le nouveau système (en tant qu'utilisateur : nix refuse, en root,
#    un dépôt git qui ne lui appartient pas) ;
# 3. l'active AU PROCHAIN DÉMARRAGE (`boot`), sans toucher à la session en cours.
#    Retour arrière possible au menu de boot.
# Si la construction échoue (paquet cassé dans nixpkgs…), flake.lock est remis
# dans son état précédent : rien n'est changé.
# Journal : journalctl -u lucas-auto-upgrade
{ pkgs, username, ... }:
let
  repo = "/home/${username}/nix-desktop-config";
in
{
  systemd.services.lucas-auto-upgrade = {
    description = "Mise à jour hebdomadaire de NixOS (flake)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [
      nix
      git
      coreutils
      util-linux # runuser
      hostname
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu
      asUser() { runuser -u ${username} -- "$@"; }
      nixf() { asUser nix --extra-experimental-features "nix-command flakes" "$@"; }

      backup=$(mktemp)
      cp ${repo}/flake.lock "$backup"
      restore() {
        echo "Échec : flake.lock remis dans son état précédent" >&2
        cat "$backup" > ${repo}/flake.lock # garde le propriétaire du fichier
        asUser git -C ${repo} add flake.lock
      }

      nixf flake update --flake ${repo}
      asUser git -C ${repo} add flake.lock
      if ! system=$(nixf build --no-link --print-out-paths \
          "${repo}#nixosConfigurations.$(hostname).config.system.build.toplevel"); then
        restore
        exit 1
      fi
      nix-env -p /nix/var/nix/profiles/system --set "$system"
      "$system/bin/switch-to-configuration" boot
      rm -f "$backup"
    '';
  };

  systemd.timers.lucas-auto-upgrade = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true; # rattrape le passage manqué si la machine était éteinte
      RandomizedDelaySec = "1h";
    };
  };
}
