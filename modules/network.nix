# IP fixe via NetworkManager, propre à chaque host (lucas.network.address) :
#   tour : 192.168.1.200 (l'IP de l'ancienne Kali) ; VM : 192.168.1.201.
# Le profil n'est lié à aucune interface : il s'applique au premier port
# Ethernet, que ce soit enp0s3 (VirtualBox) ou le port de la tour.
{ config, lib, ... }:
{
  options.lucas.network.address = lib.mkOption {
    type = lib.types.str;
    example = "192.168.1.200";
    description = "Adresse IPv4 fixe de la machine (réseau 192.168.0.0/23).";
  };

  config.networking.networkmanager = {
    enable = true;
    ensureProfiles.profiles.lan-statique = {
      connection = {
        id = "lan-statique";
        type = "ethernet";
        autoconnect = true;
        autoconnect-priority = 100;
      };
      ipv4 = {
        method = "manual";
        address1 = "${config.lucas.network.address}/23,192.168.0.1";
        dns = "192.168.1.3;"; # AdGuard
        dns-search = "local;";
      };
      ipv6.method = "disabled";
    };
  };
}
