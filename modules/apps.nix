# Applications graphiques du quotidien
{ pkgs, username, ... }:
{
  programs.firefox.enable = true;
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [ obs-pipewire-audio-capture ];
  };

  # ── Suite ArtCraft (nix-craftapps) ────────────────────────────────
  programs.craftapps = {
    enable = true;
    apps = {
      photocraft.enable = true;
      pdfcraft.enable = true;
      wordcraft.enable = true;
      gridcraft.enable = true;
      cadcraft.enable = true;
    };
  };

  # ── Claude Desktop (officiel) + Cowork ────────────────────────────
  # Cowork lance une VM QEMU/KVM : accès à /dev/kvm et /dev/vhost-vsock
  boot.kernelModules = [ "vhost_vsock" ];
  users.users.${username}.extraGroups = [ "kvm" ];

  # ── Périphériques ─────────────────────────────────────────────────
  hardware.flipperzero.enable = true; # règles udev qFlipper
  # Logitech MX Master 3 / MX Keys : Solaar (appairage Bolt/Unifying, batterie, boutons)
  hardware.logitech.wireless = {
    enable = true;
    enableGraphical = true;
  };
  # Bluetooth : gestionnaire intégré à KDE (Bluedevil) et à COSMIC

  # OpenRGB, OpenDeck (Stream Deck) : modules/peripheriques-tour.nix (tour seulement)

  environment.systemPackages = with pkgs; [
    # Navigateurs
    brave

    # Communication
    discord
    telegram-desktop
    signal-desktop

    # Notes, mots de passe (client branché sur warden.jobl1n0urs.work)
    obsidian
    bitwarden-desktop
    bitwarden-cli

    # Accès distant
    remmina
    anydesk

    # IA
    claude-desktop # .deb officiel (pkgs/claude-desktop)
    lmstudio

    # Matériel
    qFlipper

    # Multimédia (EasyEffects : service home-manager)
    mpv
    celluloid
    loupe # images
    papers # PDF

    # Fonds d'écran animés Wallpaper Engine : plugin KDE (modules/plasma.nix),
    # linux-wallpaperengine pour COSMIC
    linux-wallpaperengine

    # Espace disque
    baobab
    gdu
    dust
    ncdu

    # Infos système (neofetch a été retiré de nixpkgs : alias neofetch → fastfetch)
    fastfetch
  ];
}
