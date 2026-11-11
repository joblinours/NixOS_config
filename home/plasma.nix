# KDE Plasma 6 façon macOS, décrit en Nix avec plasma-manager :
# barre de menus en haut (menu global), dock flottant en bas, thème WhiteSur sombre,
# boutons « feux tricolores » à gauche, flou et translucidité, Spotlight (KRunner),
# coin actif en haut à gauche pour la vue d'ensemble (Mission Control).
{
  pkgs,
  lib,
  ...
}:
let
  wallpaper = "${pkgs.whitesur-kde}/share/wallpapers/WhiteSur/contents/images_dark/3840x2160.jpg";

  # Ctrl+Alt+T : active / coupe le tuilage automatique Krohnkite
  tilingToggle = pkgs.writeShellApplication {
    name = "tiling-toggle";
    runtimeInputs = with pkgs; [
      kdePackages.kconfig # kreadconfig6 / kwriteconfig6
      dbus
      libnotify
    ];
    text = ''
      cur="$(kreadconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled --default false)"
      if [ "$cur" = true ]; then new=false; msg="Tuilage automatique désactivé"; else new=true; msg="Tuilage automatique activé"; fi
      kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled "$new"
      dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure
      notify-send -a KWin -i view-grid "$msg"
    '';
  };
in
{
  home.packages = [ tilingToggle ];

  # Démarrage auto avec la session KDE : Solaar (Logitech), serveur Vicinae
  xdg.configFile."autostart/solaar.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Solaar
    Exec=solaar --window=hide
    OnlyShowIn=KDE;
  '';
  # ── Vicinae façon Spotlight (anglais seulement : pas de traduction disponible) ──
  # Thème « macOS sombre » : couleurs système d'Apple
  xdg.dataFile."vicinae/themes/macos-sombre.toml".text = ''
    [meta]
    name = "macOS sombre"
    description = "Couleurs système de macOS (mode sombre)"
    variant = "dark"
    inherits = "vicinae-dark"

    [colors.accents]
    blue = "#0a84ff"
    green = "#30d158"
    magenta = "#ff375f"
    orange = "#ff9f0a"
    red = "#ff453a"
    yellow = "#ffd60a"
    cyan = "#64d2ff"
    purple = "#bf5af2"

    [colors.core]
    accent = "colors.accents.blue"
    accent_foreground = "#ffffff"
    background = "#1e1e1e"
    foreground = "#ffffff"
    secondary_background = "#2c2c2e"
    border = "#3a3a3c"

    [colors.main_window]
    border = "#48484a"
    footer = { background = "#242426" }

    [colors.text]
    default = "colors.core.foreground"
    muted = "#98989d"
    placeholder = "#8e8e93"
    danger = "colors.accents.red"
    success = "colors.accents.green"
    selection = { background = "colors.accents.blue", foreground = "#ffffff" }

    [colors.input]
    border = "#3a3a3c"
    border_focus = "colors.accents.blue"
    border_error = "colors.accents.red"

    [colors.list.item.hover]
    foreground = "#ffffff"
    secondary_foreground = "#c7c7cc"

    [colors.list.item.selection]
    background = "colors.accents.blue"
    foreground = "#ffffff"
    secondary_background = "colors.accents.blue"
    secondary_foreground = "#ffffff"

    [colors.grid.item]
    background = "#2c2c2e"
    hover = { outline = "colors.accents.blue" }
    selection = { outline = "colors.accents.blue" }

    [colors.loading]
    bar = "colors.accents.blue"
    spinner = "#ffffff"
  '';

  # Réglages gérés par Nix, importés par settings.json (que Vicinae doit pouvoir
  # modifier lui-même : il n'est donc pas géré par Nix)
  xdg.configFile."vicinae/nix.json".text = builtins.toJSON {
    font.normal.family = "Inter";
    theme = {
      dark = {
        name = "macos-sombre";
        icon_theme = "WhiteSur-dark";
      };
      light = {
        name = "macos-sombre";
        icon_theme = "WhiteSur-dark";
      };
    };
    launcher_window = {
      opacity = 0.82; # < 1 : nécessaire pour l'effet verre
      material = "auto"; # « liquid_glass » si disponible, sinon flou
      rounding = 16;
      client_side_decorations = {
        enabled = true;
        border_width = 1;
        shadow_size = 18;
      };
      compact_mode.enabled = true; # barre seule tant qu'on n'a rien tapé, comme Spotlight
      size = {
        width = 720;
        height = 450;
      };
    };
    search_files_in_root = true; # cherche aussi les fichiers, comme Spotlight
    escape_key_behavior = "close_window";
    pop_to_root_on_close = true;
  };
  home.activation.vicinaeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/vicinae/settings.json"
    if [ ! -e "$f" ] || ! grep -q "nix.json" "$f"; then
      [ -e "$f" ] && mv "$f" "$f.avant-nix"
      mkdir -p "$(dirname "$f")"
      printf '{\n\t"imports": ["./nix.json"]\n}\n' > "$f"
    fi
  '';

  # KWin peut démarrer avant que plasma-manager ait écrit kwinrc (touche Windows →
  # Vicinae, effets…) : on lui fait relire sa config une fois la session ouverte
  xdg.configFile."autostart/kwin-reconfigure.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Recharger la config KWin
    Exec=sh -c "sleep 3 && ${pkgs.dbus}/bin/dbus-send --session --dest=org.kde.KWin --type=method_call /KWin org.kde.KWin.reconfigure"
    OnlyShowIn=KDE;
  '';
  xdg.configFile."autostart/vicinae.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Vicinae
    Exec=vicinae server --replace
    OnlyShowIn=KDE;
  '';

  # Style des applis Qt : Kvantum avec le thème WhiteSur (menus translucides)
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=WhiteSurDark
  '';

  # Applis GTK (Firefox, Celluloid, Loupe…) au même style
  gtk = {
    enable = true;
    theme = {
      name = "WhiteSur-Dark";
      package = pkgs.whitesur-gtk-theme;
    };
    iconTheme = {
      name = "WhiteSur-dark";
      package = pkgs.whitesur-icon-theme;
    };
    cursorTheme = {
      name = "macOS";
      package = pkgs.apple-cursor;
      size = 24;
    };
  };

  programs.plasma = {
    enable = true;

    # Éléments du thème WhiteSur posés un par un : le « look-and-feel » complet
    # imposerait sa propre disposition (écrasant barre et dock) et son curseur.
    workspace = {
      theme = "WhiteSur-dark"; # thème Plasma (panneaux, widgets)
      splashScreen.theme = "com.github.vinceliuice.WhiteSur-dark";
      colorScheme = "WhiteSurDark";
      iconTheme = "WhiteSur-dark";
      widgetStyle = "kvantum";
      cursor = {
        theme = "macOS";
        size = 24;
      };
      # Décorations WhiteSur : boutons ronds rouge/jaune/vert
      windowDecorations = {
        library = "org.kde.kwin.aurorae";
        theme = "__aurorae__svg__WhiteSur-dark";
      };
      inherit wallpaper;
    };

    kscreenlocker.appearance.wallpaper = wallpaper;

    fonts = {
      general = {
        family = "Inter";
        pointSize = 10;
      };
      fixedWidth = {
        family = "MesloLGS Nerd Font";
        pointSize = 10;
      };
      small = {
        family = "Inter";
        pointSize = 8;
      };
      toolbar = {
        family = "Inter";
        pointSize = 10;
      };
      menu = {
        family = "Inter";
        pointSize = 10;
      };
      windowTitle = {
        family = "Inter";
        pointSize = 10;
        weight = "bold";
      };
    };

    panels = [
      # Barre de menus : logo, menu de l'appli active, état du système, horloge
      {
        location = "top";
        height = 28;
        floating = false;
        opacity = "translucent";
        widgets = [
          { kickoff.icon = "nix-snowflake-white"; }
          "org.kde.plasma.appmenu"
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.systemtray"
          {
            digitalClock = {
              time.format = "24h";
              date = {
                enable = true;
                position = "besideTime";
              };
            };
          }
        ];
      }
      # Dock : flottant, centré, se pousse quand une fenêtre le recouvre
      {
        location = "bottom";
        height = 56;
        floating = true;
        alignment = "center";
        lengthMode = "fit";
        hiding = "dodgewindows";
        opacity = "translucent";
        widgets = [
          {
            iconTasks.launchers = [
              "applications:org.kde.dolphin.desktop"
              "applications:firefox.desktop"
              "applications:brave-browser.desktop"
              "applications:com.mitchellh.ghostty.desktop"
              "applications:code.desktop"
              "applications:obsidian.desktop"
              "applications:discord.desktop"
              "applications:com.anthropic.Claude.desktop"
              "applications:systemsettings.desktop"
            ];
          }
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.trash"
        ];
      }
    ];

    kwin = {
      # Bureaux virtuels (workspaces) : raccourcis plus bas
      virtualDesktops = {
        number = 4;
        rows = 1;
        names = [
          "1"
          "2"
          "3"
          "4"
        ];
      };

      # Boutons à gauche, comme sur macOS
      titlebarButtons = {
        left = [
          "close"
          "minimize"
          "maximize"
        ];
        right = [ ];
      };
      effects = {
        blur.enable = true; # verre dépoli sous les panneaux et menus translucides
        translucency.enable = true;
        minimization.animation = "magiclamp"; # effet « génie » de macOS
        wobblyWindows.enable = false;
        desktopSwitching.animation = "slide";
      };
    };

    # KRunner (Spotlight) reste sur Alt+Espace ; la touche Windows ouvre Vicinae
    krunner.position = "center";

    # ── Lanceurs d'applis ───────────────────────────────────────────
    hotkeys.commands = {
      # Touche Windows seule (raccourci global ordinaire dans Plasma 6) + Win+Espace
      vicinae = {
        name = "Vicinae";
        keys = [
          "Meta"
          "Meta+Space"
        ];
        command = "vicinae toggle";
      };
      ghostty = {
        name = "Terminal Ghostty";
        key = "Meta+T";
        command = "ghostty";
      };
      brave = {
        name = "Brave";
        key = "Meta+C";
        command = "brave";
      };
      discord = {
        name = "Discord";
        key = "Meta+D";
        command = "discord";
      };
      claude = {
        name = "Claude Desktop";
        key = "Meta+A";
        command = "claude-desktop";
      };
      tiling = {
        name = "Basculer le tuilage automatique";
        key = "Ctrl+Alt+T";
        command = "tiling-toggle";
      };
    };

    # ── Raccourcis KDE ──────────────────────────────────────────────
    shortcuts = {
      "services/org.kde.krunner.desktop"._launch = "Alt+Space";
      # Le menu des applis rend la touche Windows à Vicinae (il garde Alt+F1)
      plasmashell."activate application launcher" = "Alt+F1";
      # Ctrl+Alt+T sert au tuilage (au lieu d'ouvrir Konsole)
      "services/org.kde.konsole.desktop"._launch = [ ];

      kwin = {
        # Libère Win+T / Win+D (éditeur de tuiles / bureau) pour Ghostty et Discord
        "Edit Tiles" = [ ];
        "Show Desktop" = [ ];

        # Win+↑ : fenêtre maximisée sur l'écran actuel (bascule) ; Win+↓ : réduire
        "Window Quick Tile Top" = [ ];
        "Window Quick Tile Bottom" = [ ];
        "Window Maximize" = "Meta+Up";
        "Window Minimize" = "Meta+Down";

        # Bureaux : Ctrl+Alt+←/→, vue d'ensemble Ctrl+Alt+↑,
        # Win+1…4 pour y aller, Win+Maj+1…4 pour y envoyer la fenêtre
        # (variantes AZERTY & é " ' incluses)
        "Switch One Desktop to the Left" = "Ctrl+Alt+Left";
        "Switch One Desktop to the Right" = "Ctrl+Alt+Right";
        "Overview" = [
          "Ctrl+Alt+Up"
          "Meta+W"
        ];
        "Switch to Desktop 1" = [
          "Meta+1"
          "Meta+&"
        ];
        "Switch to Desktop 2" = [
          "Meta+2"
          "Meta+É"
        ];
        "Switch to Desktop 3" = [
          "Meta+3"
          "Meta+\""
        ];
        "Switch to Desktop 4" = [
          "Meta+4"
          "Meta+'"
        ];
        "Window to Desktop 1" = "Meta+Shift+1";
        "Window to Desktop 2" = "Meta+Shift+2";
        "Window to Desktop 3" = "Meta+Shift+3";
        "Window to Desktop 4" = "Meta+Shift+4";
      };
    };

    configFile = {
      # Ancien mécanisme « touche seule » de KWin, ignoré par Plasma 6 : vidé pour
      # éviter un double appel (Vicinae ouvert puis refermé)
      kwinrc.ModifierOnlyShortcuts.Meta = "";
      # Mission Control : vue d'ensemble en poussant la souris dans le coin haut-gauche
      kwinrc."Effect-overview".BorderActivate = 7;
      # Coins arrondis (KDE-Rounded-Corners) ; tuilage Krohnkite inactif au
      # démarrage de session (Ctrl+Alt+T pour le basculer)
      kwinrc.Plugins = {
        kwin4_effect_shapecornersEnabled = true;
        krohnkiteEnabled = false;
      };
    };
  };
}
