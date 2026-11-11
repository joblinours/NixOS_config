# Module maison avec ses propres options : lucas.dfir.*
# Les outils lourds (volatility3…) sont dans `nix develop .#dfir`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lucas.dfir;
in
{
  options.lucas.dfir = {
    enable = lib.mkEnableOption "les outils DFIR au niveau système" // {
      default = true;
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.radare2 ]";
      description = "Outils supplémentaires à installer.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      (with pkgs; [
        # Disque / fichiers
        sleuthkit # fls, icat, mmls, tsk_recover…
        autopsy
        foremost
        testdisk # + photorec
        ddrescue
        exiftool
        hexyl
        binwalk

        # Malware
        yara
        capa # paquet maison (binaire officiel Mandiant)
        flare-floss
        detect-it-easy # diec / die
        upx
        pev # readpe, pesec…

        # Paquet maison
        triage
      ])
      ++ cfg.extraPackages;
  };
}
