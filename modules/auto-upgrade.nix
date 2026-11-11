# Mise à jour automatique hebdomadaire (paquets, Oh My Zsh, plugins…).
# 1. met à jour flake.lock dans ~/nix-desktop-config (en tant qu'utilisateur) ;
# 2. construit le nouveau système et l'active AU PROCHAIN DÉMARRAGE (`boot`),
#    sans toucher à la session en cours. Retour arrière possible au menu de boot.
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
      nixos-rebuild-ng
      util-linux # runuser
      hostname
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      runuser -u ${username} -- nix --extra-experimental-features "nix-command flakes" flake update --flake ${repo}
      runuser -u ${username} -- git -C ${repo} add flake.lock
      nixos-rebuild boot --flake "${repo}#$(hostname)"
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
