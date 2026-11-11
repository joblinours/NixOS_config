# Gaming — d'après https://www.talesign.com/blog/nixology/sq-gaming-on-nixos
# (pilote NVIDIA : voir nvidia.nix, modules ouverts recommandés pour les RTX 40)
{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # jeux 32 bits, Wine/Proton
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true; # session « Steam Big Picture » façon Steam Deck
    remotePlay.openFirewall = false;
  };
  programs.gamescope.enable = true;
  programs.gamemode.enable = true; # `gamemoderun %command%` dans les options de lancement Steam

  # Proton-GE : installer/mettre à jour avec protonup-qt, puis le choisir dans
  # Propriétés du jeu → Compatibilité
  environment.sessionVariables.STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";

  environment.systemPackages = with pkgs; [
    protonup-qt
    mangohud # overlay : `mangohud %command%` dans Steam
    lutris
    heroic
  ];
}
