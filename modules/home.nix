{ username, ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup"; # ne casse pas si un dotfile existe déjà
  # KDE réécrit certains fichiers (thème GTK…) à chaque connexion : sans ceci, la
  # sauvegarde .hm-backup du passage précédent bloque toute l'activation
  home-manager.overwriteBackup = true;
  home-manager.extraSpecialArgs = { inherit username; };
  home-manager.users.${username} = import ../home/jobl1n0urs.nix;
}
