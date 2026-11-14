{
  pkgs,
  lib,
  username,
  osConfig,
  ...
}:
let
  # VM VirtualBox : le GPU virtuel n'offre qu'OpenGL 4.1, Ghostty exige 4.3.
  # → rendu logiciel Mesa (llvmpipe, OpenGL 4.5) pour Ghostty seulement.
  ghosttyVm = pkgs.symlinkJoin {
    name = "ghostty-vm";
    paths = [ pkgs.ghostty ];
    meta.mainProgram = "ghostty";
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/ghostty --set LIBGL_ALWAYS_SOFTWARE 1
      # Les lanceurs (.desktop, D-Bus, systemd) pointent vers le binaire d'origine
      for f in $(find -L $out/share/applications $out/share/dbus-1 $out/share/systemd $out/lib/systemd -type f 2>/dev/null); do
        if grep -q "${pkgs.ghostty}/bin/ghostty" "$f"; then
          cp --remove-destination "$(readlink -f "$f")" "$f"
          substituteInPlace "$f" --replace-fail "${pkgs.ghostty}/bin/ghostty" "$out/bin/ghostty"
        fi
      done
    '';
  };

  # Config powerlevel10k : si home/p10k.zsh existe (copie de ~/.p10k.zsh après
  # `p10k configure`), elle est utilisée ; sinon le preset « rainbow » fourni par p10k.
  p10kPerso = ./p10k.zsh;
  p10kConfig =
    if builtins.pathExists p10kPerso then
      p10kPerso
    else
      "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/config/p10k-rainbow.zsh";
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05"; # ne pas changer ensuite

  imports = [ ./plasma.nix ];

  home.packages = with pkgs; [
    bat
    eza
    autojump # plugin Oh My Zsh « autojump » (commande j)
    zsh-completions # complétions supplémentaires
    imagemagick # plugin « catimg »
  ];

  # Autopsy : son paquet ne fournit pas d'entrée de menu
  xdg.desktopEntries.autopsy = {
    name = "Autopsy";
    genericName = "Analyse forensique";
    exec = "autopsy";
    icon = "system-search";
    categories = [
      "System"
      "Security"
    ];
  };

  # ── zsh + Oh My Zsh + powerlevel10k ───────────────────────────────
  # Prompt : home/p10k.zsh (ta config, à l'identique)
  home.file.".p10k.zsh".source = p10kConfig;

  programs.zsh = {
    enable = true;
    # Équivalents des plugins zsh-autosuggestions et zsh-syntax-highlighting
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history.size = 50000;

    # Oh My Zsh vient de nixpkgs : mis à jour avec le système (MAJ auto hebdo,
    # modules/auto-upgrade.nix). Le thème reste powerlevel10k (plugin ci-dessous).
    oh-my-zsh = {
      enable = true;
      plugins = [
        # Tes plugins
        "git"
        "gitfast"
        "sudo" # Échap ×2 : ajoute sudo devant la commande
        "web-search" # google <mots>, ddg <mots>…
        "autojump"
        "history"
        "jsontools"
        "fzf"
        "aliases" # als : liste les alias
        "catimg"
        "extract" # x <archive>
        # Dev
        "docker"
        "docker-compose"
        "python"
        "rust"
        "golang"
        "npm"
        # Confort
        "colored-man-pages"
        "copypath"
        "copyfile"
        "z"
        # Sys/sécu
        "systemd"
        "ssh-agent"
        "nmap"
      ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = lib.mkMerge [
      # Instant prompt : doit être tout en haut du .zshrc
      (lib.mkBefore ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      ''
        [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
      ''
    ];

    shellAliases = {
      ll = "eza -la --git";
      cat = "bat --paging=never";
      rebuild = "nh os switch";
      cfg = "cd ~/nix-desktop-config";
      lg = "lazygit";
      lzd = "lazydocker";
      lssh = "lazyssh";
      neofetch = "fastfetch"; # neofetch a été retiré de nixpkgs
      open = "xdg-open"; # comme sur macOS : ouvre avec l'appli par défaut
      # plaso n'est pas dans nixpkgs : image Docker officielle
      plaso = ''docker run --rm -it -v "$PWD:/data" log2timeline/plaso'';
    };
  };

  # ── Ghostty ───────────────────────────────────────────────────────
  programs.ghostty = {
    enable = true;
    package = if osConfig.lucas.vm.enable then ghosttyVm else pkgs.ghostty;
    enableZshIntegration = true;
    # Style macOS : couleurs Apple, fond translucide flouté par KWin
    settings = {
      theme = "Apple System Colors";
      font-family = "MesloLGS Nerd Font"; # requis par powerlevel10k
      font-size = 12;
      background-opacity = 0.85;
      background-blur = true;
      window-padding-x = 8;
      window-padding-y = 8;
      copy-on-select = "clipboard";
      confirm-close-surface = false;
      keybind = [
        "ctrl+shift+t=new_tab"
        "ctrl+shift+d=new_split:down" # séparation horizontale (terminal en dessous)
        "ctrl+shift+r=new_split:right" # séparation verticale (terminal à droite)
      ];
    };
  };

  # ── Outils shell ──────────────────────────────────────────────────
  programs.fzf = {
    enable = true; # Ctrl+R amélioré
    enableZshIntegration = false; # fourni par le plugin Oh My Zsh « fzf »
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # .envrc contenant `use flake`
  };

  programs.git = {
    enable = true;
    # Identité à compléter :
    # settings.user = { name = "Lucas"; email = "…"; };
  };

  # ── VS Code ───────────────────────────────────────────────────────
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    # Les extensions restent installables depuis VS Code (profil mutable)
  };

  # ── Mixer / effets audio ──────────────────────────────────────────
  services.easyeffects.enable = true;
}
