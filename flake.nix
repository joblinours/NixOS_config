{
  description = "NixOS de Lucas — Plasma, dev, pentest, DFIR (VM VirtualBox, tour RTX 4060, laptop)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Partitionnement déclaratif (hosts/*/disk.nix)
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets chiffrés dans le dépôt (secrets/secrets.yaml)
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Flatpak déclaratif (OpenDeck, depuis Flathub)
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Suite ArtCraft (PhotoCraft, PdfCraft…) empaquetée en Nix
    nix-craftapps.url = "github:olafkfreund/nix-craftapps";
    nix-craftapps.inputs.nixpkgs.follows = "nixpkgs";

    # Configuration déclarative de KDE Plasma 6 (barre, dock, thème, effets…)
    plasma-manager.url = "github:nix-community/plasma-manager";
    plasma-manager.inputs.nixpkgs.follows = "nixpkgs";
    plasma-manager.inputs.home-manager.follows = "home-manager";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      disko,
      sops-nix,
      nix-flatpak,
      nix-craftapps,
      plasma-manager,
      ...
    }@inputs:
    let
      # ── À adapter ────────────────────────────────────────────────
      username = "jobl1n0urs";
      # ─────────────────────────────────────────────────────────────

      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        # Pour les devShells/paquets du flake (le système a allowUnfree = true)
        config.allowUnfreePredicate = p: builtins.elem (nixpkgs.lib.getName p) [ "volatility3" ];
      };

      mkHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs username hostname; };
          modules = [
            { nixpkgs.hostPlatform = system; }
            { nixpkgs.overlays = [ self.overlays.default ]; }
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            nix-flatpak.nixosModules.nix-flatpak
            nix-craftapps.nixosModules.default
            { home-manager.sharedModules = [ plasma-manager.homeModules.plasma-manager ]; }
            home-manager.nixosModules.home-manager
            ./hosts/${hostname}
          ];
        };
    in
    {
      # sudo nixos-rebuild switch --flake .#nix-desktop-vm   (VM VirtualBox de test)
      # sudo nixos-rebuild switch --flake .#nix-desktop      (tour, RTX 4060)
      # sudo nixos-rebuild switch --flake .#nix-laptop       (laptop)
      nixosConfigurations = {
        nix-desktop-vm = mkHost "nix-desktop-vm";
        nix-desktop = mkHost "nix-desktop";
        nix-laptop = mkHost "nix-laptop";
      };

      # Paquets maison : nix build .#triage / .#capa / .#claude-desktop
      packages.${system} = {
        triage = pkgs.callPackage ./pkgs/triage/package.nix { };
        capa = pkgs.callPackage ./pkgs/capa/package.nix { };
        claude-desktop = self.nixosConfigurations.nix-desktop.pkgs.claude-desktop;
        default = self.packages.${system}.triage;
      };

      overlays.default = final: prev: {
        triage = final.callPackage ./pkgs/triage/package.nix { };
        capa = final.callPackage ./pkgs/capa/package.nix { };
        awesome-terminal-fonts = final.callPackage ./pkgs/awesome-terminal-fonts/package.nix { };
        # Démon du plugin OpenDeck Sho Metrics (modules/peripheriques-tour.nix)
        sho-metrics-helper = final.callPackage ./pkgs/sho-metrics-helper/package.nix { };
        # .deb officiel d'Anthropic dans un environnement FHS (voir pkgs/claude-desktop)
        claude-desktop = final.callPackage ./pkgs/claude-desktop/package.nix { };

        # Correctif : VS Code 1.144 a déplacé ripgrep, le postPatch de nixpkgs 26.05
        # vise l'ancien chemin et le build échoue (rm: cannot remove …/rg).
        # À retirer quand nixpkgs sera corrigé (le build passera sans).
        vscode = prev.vscode.overrideAttrs (old: {
          postPatch =
            builtins.replaceStrings
              [ "resources/app/node_modules/@vscode/ripgrep/bin/rg" ]
              [ "resources/app/node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/linux-x64/rg" ]
              (old.postPatch or "");
        });

        # Correctif : AnyDesk a remplacé l'archive 8.1.0 sur son serveur sans changer
        # l'URL → hash mismatch dans nixpkgs 26.05. Si ça recasse : mettre le hash
        # « got: » affiché par le build. À retirer quand nixpkgs sera à jour.
        anydesk = prev.anydesk.overrideAttrs (old: {
          src = old.src.overrideAttrs {
            outputHash = "sha256-zS5P2eyTHZY7cBW8mQ2Q6M0lXcx9VZZTtpG3Bb6u7IQ=";
          };
        });
      };

      # nix develop        → outils Nix + sops/age
      # nix develop .#dfir → boîte à outils forensique
      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            nil
            nvd
            sops
            age
            ssh-to-age
          ];
        };
        dfir = import ./shells/dfir.nix { inherit pkgs; };
      };

      # nix flake check : évalue les 2 systèmes et construit les paquets maison
      checks.${system} = {
        inherit (self.packages.${system}) triage capa;
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
