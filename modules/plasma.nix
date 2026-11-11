# KDE Plasma 6 façon macOS : le bureau.
# Le look (barre, dock, thème, effets) est décrit dans home/plasma.nix (plasma-manager).
{ pkgs, ... }:
{
  services.desktopManager.plasma6.enable = true;

  # Écran de connexion façon macOS (thème WhiteSur, Qt6), sous Wayland
  services.displayManager = {
    defaultSession = "plasma";
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "WhiteSur-dark";
    };
  };

  # Applis KDE inutiles ici
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa # lecteur audio (on a mpv/Celluloid)
    khelpcenter
    krdp
  ];

  environment.systemPackages = with pkgs; [
    # Thème macOS : look-and-feel, couleurs, décorations « feux tricolores »,
    # Kvantum (translucidité), SDDM, icônes, curseur, GTK
    whitesur-kde
    whitesur-icon-theme
    whitesur-gtk-theme
    apple-cursor
    kdePackages.qtstyleplugin-kvantum
    kde-rounded-corners # coins arrondis + contour des fenêtres

    # Fonds animés Wallpaper Engine (clic droit sur le bureau → Configurer le bureau)
    kdePackages.wallpaper-engine-plugin

    # Tuilage automatique façon Hyprland, inactif par défaut : Ctrl+Alt+T (home/plasma.nix)
    kdePackages.krohnkite

    # Lanceur façon Raycast, sur la touche Windows (home/plasma.nix)
    vicinae

    # Outils KDE utiles
    mousepad # éditeur de texte simple
    kdePackages.ark
    kdePackages.kcalc
    kdePackages.spectacle # captures d'écran
    kdePackages.partitionmanager
  ];

  # Police proche de San Francisco (police système d'Apple)
  fonts.packages = [ pkgs.inter ];
}
