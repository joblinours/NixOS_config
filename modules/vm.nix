# Contournements propres à la VM VirtualBox (lucas.vm.enable, activé par hosts/nix-desktop-vm).
# Le GPU virtuel (VMware SVGA II) n'offre qu'OpenGL 4.1 et ne sait pas allouer les
# buffers « scanout » que demandent les apps Electron/Chromium sous Wayland.
# Rien de tout ça ne s'applique à la tour (RTX 4060).
# Ghostty (OpenGL 4.3 requis) est enveloppé en rendu logiciel dans home/jobl1n0urs.nix.
{ config, lib, ... }:
let
  cfg = config.lucas.vm;
  noGpu = "--disable-gpu";
in
{
  options.lucas.vm.enable = lib.mkEnableOption "les contournements GPU de la VM VirtualBox";

  config = lib.mkIf cfg.enable {
    # mkAfter : appliqué APRÈS l'overlay du flake (qui définit claude-desktop)
    nixpkgs.overlays = lib.mkAfter [
      (final: prev: {
        # Electron/Chromium : rendu logiciel (sinon « Cannot create bo … Scanout » puis crash)
        vscode = prev.vscode.override { commandLineArgs = noGpu; };
        discord = prev.discord.override { commandLineArgs = noGpu; };
        obsidian = prev.obsidian.override { commandLineArgs = noGpu; };
        signal-desktop = prev.signal-desktop.override { commandLineArgs = noGpu; };
        brave = prev.brave.override { commandLineArgs = noGpu; };
        # (.override viserait buildFHSEnv, pas le paquet : on rappelle le paquet)
        claude-desktop = final.callPackage ../pkgs/claude-desktop/package.nix { extraArgs = noGpu; };
      })
    ];
  };
}
