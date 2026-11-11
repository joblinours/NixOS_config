{ pkgs, ... }:
{
  # Bureau : KDE Plasma 6 façon macOS (plasma.nix)

  # ── Son : PipeWire ────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # ── Matériel / services de bureau ─────────────────────────────────
  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;
  services.printing.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true; # corbeille, montages réseau dans le gestionnaire de fichiers

  # ── Polices ───────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.meslo-lg # police du terminal
    # Icônes du prompt powerlevel10k (mode « awesome-fontconfig », home/p10k.zsh)
    awesome-terminal-fonts
    powerline-fonts
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
  ];

  # Associe les icônes Awesome Terminal Fonts aux polices de repli
  fonts.fontconfig.localConf = builtins.readFile "${pkgs.awesome-terminal-fonts}/etc/fonts/conf.d/10-symbols.conf";
}
