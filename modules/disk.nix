# Partitionnement disko commun : GPT, ESP 1 Gio, btrfs avec sous-volumes.
# Disque système choisi par l'host : lucas.disk.device = "/dev/sda";
# Disques de données facultatifs : lucas.disk.dataDevices = [ "/dev/sda" "/dev/sdb" ];
#   → réunis en UN volume btrfs monté sur /data (données « single » : l'espace
#     s'additionne ; métadonnées en raid1 si 2 disques ou plus).
# ⚠ `disko --mode disko` EFFACE tous ces disques.
{ config, lib, ... }:
let
  cfg = config.lucas.disk;
  mountOptions = [
    "compress=zstd"
    "noatime"
  ];

  # Disques de données : data1, data2, … ; le volume btrfs est créé sur le
  # DERNIER, en y incluant les partitions des autres (créées avant lui)
  dataNames = lib.imap1 (i: _: "data${toString i}") cfg.dataDevices;
  lastData = lib.last dataNames;
  otherParts = map (n: "/dev/disk/by-partlabel/disk-${n}-data") (lib.init dataNames);
  dataDisk =
    name: device:
    lib.nameValuePair name {
      type = "disk";
      inherit device;
      content = {
        type = "gpt";
        partitions.data = {
          size = "100%";
          content = lib.mkIf (name == lastData) {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "data"
              "-d"
              "single"
              "-m"
              (if otherParts == [ ] then "dup" else "raid1")
            ]
            ++ otherParts;
            subvolumes."@data" = {
              mountpoint = "/data";
              mountOptions = mountOptions ++ [ "nofail" ];
            };
          };
        };
      };
    };
in
{
  options.lucas.disk = {
    device = lib.mkOption {
      type = lib.types.str;
      example = "/dev/nvme0n1";
      description = "Disque système (sera entièrement effacé par disko).";
    };
    dataDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "/dev/sda"
        "/dev/sdb"
      ];
      description = "Disques de données réunis en un volume btrfs sur /data (effacés par disko).";
    };
  };

  config.disko.devices.disk =
    lib.listToAttrs (lib.zipListsWith dataDisk dataNames cfg.dataDevices)
    // {
      main = {
        type = "disk";
        device = config.lucas.disk.device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    inherit mountOptions;
                  };
                  "@home" = {
                    mountpoint = "/home";
                    inherit mountOptions;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    inherit mountOptions;
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    inherit mountOptions;
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    inherit mountOptions;
                  };
                };
              };
            };
          };
        };
      };
    };
}
