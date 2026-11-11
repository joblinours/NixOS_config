{
  config,
  lib,
  pkgs,
  username,
  ...
}:
{
  options.lucas.vbox.enable = lib.mkEnableOption "VirtualBox hôte";

  config = lib.mkMerge [
    {
      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
      };
      environment.systemPackages = with pkgs; [
        lazydocker
        docker-compose
      ];
    }

    (lib.mkIf config.lucas.vbox.enable {
      virtualisation.virtualbox.host = {
        enable = true;
        enableExtensionPack = true; # USB 2/3, RDP — compilé localement (long)
      };
      users.users.${username}.extraGroups = [ "vboxusers" ];
    })
  ];
}
