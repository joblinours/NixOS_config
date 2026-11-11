{ pkgs, username, ... }:
{
  # ── Nix ───────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nixpkgs.config.allowUnfree = true;

  # ── Démarrage ─────────────────────────────────────────────────────
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 15; # entrées de générations dans le menu
  };
  boot.loader.efi.canTouchEfiVariables = true;
  zramSwap.enable = true;

  # ── Localisation ──────────────────────────────────────────────────
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";
  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };

  # ── Utilisateur ───────────────────────────────────────────────────
  # Mot de passe : voir modules/secrets.nix (sops-nix)
  users.users.${username} = {
    isNormalUser = true;
    description = "Lucas";
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "wireshark"
      "dialout" # ports série (Flipper Zero, microcontrôleurs)
      "plugdev"
    ];
    shell = pkgs.zsh;
    # Clé publique autorisée en SSH : coller ici le contenu de ~/.ssh/id_ed25519.pub
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... lucas@kali"
    ];
  };
  users.groups.plugdev = { };
  programs.zsh.enable = true;

  # sudo demande le mot de passe (machine physique, contrairement à WSL)
  security.sudo.wheelNeedsPassword = true;

  # ── Paquets de base ───────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    nano
    curl
    wget
    htop
    btop
    tmux
    ripgrep
    fd
    jq
    tree
    unzip
    p7zip
    file
    pciutils
    usbutils
    lsof
    nvd # diff entre générations
    restic # sauvegardes (restauration de la sauvegarde Kali)
    nix-output-monitor # `nom build ...`
  ];
  environment.variables.EDITOR = "nano";
  programs.nano.enable = true;

  # nh : surcouche lisible de nixos-rebuild (`nh os switch`)
  programs.nh = {
    enable = true;
    flake = "/home/${username}/nix-desktop-config";
  };

  # Binaires précompilés (rustup, extensions VS Code, outils téléchargés)
  programs.nix-ld.enable = true;

  # Mises à jour de firmware (fwupdmgr)
  services.fwupd.enable = true;

  # Vérification mensuelle de l'intégrité btrfs
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };
}
