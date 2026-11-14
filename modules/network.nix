# Réseau via NetworkManager. Réglages propres à chaque host :
#   lucas.network.address       IP fixe en Ethernet (null = DHCP)
#   lucas.network.wifi.ssid     wifi maison sur lequel forcer une IP fixe (null = aucun)
#   lucas.network.wifi.address  IP fixe sur ce wifi (par défaut : la même qu'en Ethernet)
# tour : 192.168.1.200 (Ethernet et wifi) ; VM : 192.168.1.201 ; laptop : DHCP,
# sauf 192.168.1.202 sur le wifi maison (le pare-feu du lab bloque les 192.168.0.x).
# Les profils ne sont liés à aucune interface : 1er port Ethernet / 1re carte wifi.
# Mot de passe wifi : PAS dans le dépôt ; KDE le demande à la 1re connexion et le
# garde dans KWallet (ou `nmcli con up wifi-statique --ask`).
# Les autres wifis (créés depuis KDE) restent en DHCP.
{ config, lib, ... }:
let
  cfg = config.lucas.network;
  staticIpv4 = address: {
    method = "manual";
    address1 = "${address}/23,192.168.0.1";
    dns = "192.168.1.3;"; # AdGuard
    dns-search = "local;";
  };
in
{
  options.lucas.network = {
    address = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.1.200";
      description = "IPv4 fixe en Ethernet (réseau 192.168.0.0/23) ; null = DHCP.";
    };
    wifi = {
      ssid = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "Jobl'Internet";
        description = "SSID exact (casse comprise) du wifi maison où forcer une IP fixe ; null = DHCP partout.";
      };
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = cfg.address;
        defaultText = lib.literalExpression "config.lucas.network.address";
        example = "192.168.1.202";
        description = "IPv4 fixe sur ce wifi.";
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = cfg.wifi.ssid == null || cfg.wifi.address != null;
        message = "lucas.network.wifi.ssid est défini : il faut aussi lucas.network.wifi.address.";
      }
    ];

    networking.networkmanager = {
      enable = true;
      ensureProfiles.profiles =
        lib.optionalAttrs (cfg.address != null) {
          lan-statique = {
            connection = {
              id = "lan-statique";
              type = "ethernet";
              autoconnect = true;
              autoconnect-priority = 100;
            };
            ipv4 = staticIpv4 cfg.address;
            ipv6.method = "disabled";
          };
        }
        // lib.optionalAttrs (cfg.wifi.ssid != null) {
          # ⚠ Si l'Ethernet a la même IP, ne pas brancher les deux en même temps
          wifi-statique = {
            connection = {
              id = "wifi-statique";
              type = "wifi";
              autoconnect = true;
              autoconnect-priority = 100; # passe avant un éventuel profil DHCP du même wifi
            };
            wifi = {
              mode = "infrastructure";
              ssid = cfg.wifi.ssid;
            };
            wifi-security = {
              key-mgmt = "wpa-psk";
              psk-flags = 1; # mot de passe gardé par l'agent (KWallet), pas dans /etc
            };
            ipv4 = staticIpv4 cfg.wifi.address;
            ipv6.method = "disabled";
          };
        };
    };
  };
}
