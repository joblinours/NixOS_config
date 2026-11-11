# Flatpak déclaratif (nix-flatpak) pour les apps absentes de nixpkgs.
# Synchronisé à chaque rebuild ; mises à jour hebdomadaires.
# ⚠ Pas de remote OCI (ex. ArtCraft) : son authentificateur exige une session
# D-Bus graphique, absente du service d'installation (root) → échec en boucle.
{ ... }:
{
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      # Logiciel Stream Deck
      {
        appId = "me.amankhanna.opendeck";
        origin = "flathub";
      }
    ];

    # Supprime les Flatpak qui ne sont plus déclarés ici
    uninstallUnmanaged = true;

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
