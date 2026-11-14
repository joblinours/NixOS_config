# Périphériques de la tour — importé uniquement par hosts/nix-desktop :
# OpenRGB, OpenDeck (Stream Deck Elgato + Ajazz AKP05) et son plugin Sho Metrics
# (démon de capteurs + LACT pour la RTX 4060).
{ pkgs, ... }:
{
  # ── OpenRGB : éclairage RGB (carte mère, RAM, ventilos…) ──────────
  # Charge i2c-dev + le pilote SMBus Intel et ajoute les règles udev.
  services.hardware.openrgb = {
    enable = true;
    motherboard = "intel";
  };

  # ── OpenDeck (Flatpak) ────────────────────────────────────────────
  services.flatpak.packages = [
    {
      appId = "me.amankhanna.opendeck";
      origin = "flathub";
    }
  ];

  services.udev.packages = [
    # Accès sans root aux Stream Deck Elgato (0fd9) et aux Ajazz AKP05 / AKP05E /
    # AKP05E Pro (0300:3006/3004/3013/3014). Ajazz : plugin OpenDeck
    # « Ajazz AKP05 / Mirabox N4 » (https://github.com/ambiso/opendeck-akp05).
    # ⚠ Pas services.udev.extraRules : il écrit dans 99-local.rules, APRÈS
    # 73-seat-late.rules → le tag uaccess y est ignoré. D'où un fichier 70-*.
    (pkgs.writeTextFile {
      name = "opendeck-udev-rules";
      destination = "/etc/udev/rules.d/70-opendeck.rules";
      text = ''
        SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", TAG+="uaccess"
        KERNEL=="hidraw*", ATTRS{idVendor}=="0fd9", TAG+="uaccess"

        SUBSYSTEM=="usb", ATTRS{idVendor}=="0300", ATTRS{idProduct}=="300[46]|301[34]", MODE="0660", TAG+="uaccess"
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0300", ATTRS{idProduct}=="300[46]|301[34]", MODE="0660", TAG+="uaccess"
      '';
    })

    # Puissance CPU (cpu.power de Sho Metrics) via RAPL : rend le compteur
    # d'énergie lisible. ⚠ Lisible par tout compte local (canal auxiliaire
    # PLATYPUS, CVE-2020-8694) : acceptable sur un poste mono-utilisateur.
    (pkgs.writeTextFile {
      name = "sho-metrics-rapl-udev";
      destination = "/etc/udev/rules.d/60-sho-metrics-rapl.rules";
      text = ''
        ACTION=="add|change", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:*", RUN+="${pkgs.coreutils}/bin/chmod 0444 %S%p/energy_uj"
      '';
    })
  ];

  # ── Sho Metrics Linux (plugin OpenDeck) ───────────────────────────
  # Le plugin s'installe dans OpenDeck (.streamDeckPlugin des releases GitHub) ;
  # il lui faut Node.js (modules/dev.nix) et ce démon de capteurs.
  # LACT : capteurs NVIDIA (hotspot, VRAM…), socket /run/lactd.sock (groupe wheel).
  services.lact.enable = true;

  systemd.user.services.shometrics-linux-helper = {
    description = "Sho Metrics Linux : démon de capteurs (gRPC sur socket unix)";
    wantedBy = [ "default.target" ];
    # Le plugin lit la liste des capteurs une seule fois : attendre lactd (max 90 s)
    preStart = ''
      i=0
      while [ $i -lt 180 ] && [ ! -S /run/lactd.sock ]; do sleep 0.5; i=$((i+1)); done
    '';
    serviceConfig = {
      ExecStart = "${pkgs.sho-metrics-helper}/bin/shometrics-linux-helper";
      TimeoutStartSec = 120;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
