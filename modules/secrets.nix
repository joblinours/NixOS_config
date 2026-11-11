# Secrets avec sops-nix (chiffrement age).
#
# Clés capables de déchiffrer (déclarées dans .sops.yaml) :
#   - la clé age personnelle de Lucas (~/.config/sops/age/keys.txt) ;
#   - la clé de chaque host, dérivée de sa clé SSH /etc/ssh/ssh_host_ed25519_key.
# Le script scripts/init-secrets.sh crée secrets/secrets.yaml.
#
# Tant que secrets/secrets.yaml n'existe pas, le mot de passe initial est
# « changeme » (à changer avec `passwd`) et un avertissement s'affiche au build.
{
  config,
  lib,
  username,
  ...
}:
let
  secretsFile = ../secrets/secrets.yaml;
  hasSecrets = builtins.pathExists secretsFile;
in
{
  config = lib.mkMerge [
    (lib.mkIf hasSecrets {
      sops = {
        defaultSopsFile = secretsFile;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        # Copie de la clé perso, utile à l'installation (voir scripts/install.sh)
        age.keyFile = "/var/lib/sops-nix/key.txt";

        # Hash du mot de passe (mkpasswd -m yescrypt), déchiffré avant la création des comptes
        secrets.user-password.neededForUsers = true;
      };

      users.mutableUsers = false; # les mots de passe viennent uniquement de la config
      users.users.${username}.hashedPasswordFile = config.sops.secrets.user-password.path;
    })

    (lib.mkIf (!hasSecrets) {
      warnings = [
        "secrets/secrets.yaml absent : mot de passe initial « changeme ». Lancer scripts/init-secrets.sh."
      ];
      users.users.${username}.initialPassword = "changeme";
    })
  ];
}
