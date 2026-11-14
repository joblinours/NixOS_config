# nix-desktop-config

Poste de travail NixOS 26.05 de Lucas. Au programme :
- bureau **KDE Plasma 6 façon macOS**, Ghostty + zsh (Oh My Zsh) + powerlevel10k ;
- réseau, gaming (Steam, Proton-GE, MangoHud, Lutris, Heroic), fonds animés Wallpaper Engine ;
- dev : C, Rust, Python/uv, Node, Go, Java ;
- pentest, DFIR, ArtCraft.

Trois hosts partagent le même socle :

| Host | Cible | Spécificités |
|---|---|---|
| `nix-desktop-vm` | VM VirtualBox (test) | additions invité, `/dev/sda` |
| `nix-desktop` | tour Intel + RTX 4060 | NVIDIA, VirtualBox hôte, OpenRGB, OpenDeck (+ Ajazz AKP05, Sho Metrics) |
| `nix-laptop` | laptop GTX 1660 Ti | NVIDIA en PRIME offload, DHCP sauf wifi maison, profils d'énergie, VirtualBox hôte |

| Réglage | Valeur |
|---|---|
| Utilisateur | `jobl1n0urs` |
| IP | tour `192.168.1.200` (Ethernet et wifi), VM `192.168.1.201`, laptop DHCP sauf `192.168.1.202` sur le wifi `Jobl'Internet` (/23), passerelle `192.168.0.1`, DNS AdGuard `192.168.1.3` |
| Accès | SSH par clé uniquement |


## Structure

```
flake.nix               inputs (nixpkgs/home-manager 26.05, disko, sops-nix, nix-flatpak, claude-desktop), overlay
hosts/<host>/           default.nix (choix du disque, options) + hardware-configuration.nix
modules/default.nix     socle importé par les deux hosts
  common.nix            nix, boot systemd-boot, locale fr, utilisateur, paquets de base, nh, nix-ld
  auto-upgrade.nix      mise à jour automatique hebdomadaire (flake update + système au prochain boot)
  disk.nix              disko : GPT + ESP 1G + btrfs (@, @home, @nix, @log, @snapshots), zstd ;
                        disques de données facultatifs réunis sur /data (lucas.disk.dataDevices)
  network.nix           NetworkManager : IP fixe Ethernet (lucas.network.address) et/ou sur le wifi
                        maison (lucas.network.wifi.*), DHCP sinon
  monitoring.nix        lm_sensors, Fan Control (Flatpak) + règle udev PWM
  desktop.nix           PipeWire, Bluetooth, impression, polices (Nerd Font, Awesome Terminal Fonts)
  plasma.nix            KDE Plasma 6, écran de connexion SDDM WhiteSur, thèmes macOS, Kvantum, coins arrondis
  nvidia.nix            (tour + laptop) pilote ouvert, modesetting, nvidia-container-toolkit ;
                        laptop : PRIME offload (lucas.nvidia.hybrid, adresses dans hosts/nix-laptop/prime.nix)
  peripheriques-tour.nix (tour seulement) OpenRGB, OpenDeck + udev Elgato/Ajazz AKP05,
                        démon Sho Metrics (plugin OpenDeck) + LACT
  virtualisation.nix    Docker, lazydocker, VirtualBox hôte (lucas.vbox.enable)
  security.nix          nftables (22 seul), OpenSSH par clé, ClamAV
  apps.nix              navigateurs, messageries, Obsidian, Bitwarden, OBS, LM Studio, multimédia,
                        Claude Desktop + Cowork, ArtCraft, Solaar, Wallpaper Engine, fastfetch
  network-tools.nix     dig, traceroute, mtr…, HTTP/API (httpie, xh, hurl…), VPN (WireGuard, OpenVPN, Tailscale)
  gaming.nix            Steam + session Gamescope, gamemode, protonup-qt, MangoHud, Lutris, Heroic
  vm.nix                (VM seulement) Electron sans GPU ; Ghostty en rendu logiciel (home/)
  dev.nix               toolchains + claude-code
  pentest.nix           nmap, Burp, Wireshark, hashcat, john, exploitdb, vulnx, Ghidra
  dfir.nix              lucas.dfir.* : sleuthkit, Autopsy, yara, capa, floss, DIE, pev, triage…
  flatpak.nix           Flathub (les apps sont déclarées dans monitoring.nix / peripheriques-tour.nix)
  secrets.nix           sops-nix : mot de passe de l'utilisateur
home/jobl1n0urs.nix     zsh + Oh My Zsh + p10k, Ghostty, git, direnv, fzf, VS Code, EasyEffects, alias open
home/p10k.zsh           ta config powerlevel10k (copiée à l'identique)
home/plasma.nix         Plasma façon macOS (plasma-manager) : barre de menus, dock, thème, effets, KRunner
pkgs/                   triage (script maison), capa (binaire Mandiant), claude-desktop (.deb officiel),
                        awesome-terminal-fonts (icônes du prompt), sho-metrics-helper (démon du plugin OpenDeck)
shells/dfir.nix         nix develop .#dfir (volatility3…)
scripts/                install.sh, init-secrets.sh, add-host-key.sh, test.sh,
                        netbox-ssh-config.sh (~/.ssh/config depuis la CMDB NetBox, pour lazyssh)
```

## 1. Préparer la VM VirtualBox

- **Système :** activer EFI. Prévoir au moins 8 Go de RAM et 4 vCPU.
- **Affichage :** VMSVGA, accélération 3D, 128 Mo de vidéo.
- **Disque :** au moins 60 Go (VDI dynamique).
- **Réseau :** carte 1 en **accès par pont** sur la carte physique. C'est obligatoire pour obtenir 192.168.1.201.
- **ISO :** NixOS 26.05 *minimal* (https://nixos.org/download).

## 2. Avant l'installation (sur ton poste actuel)

1. Colle ta clé publique SSH dans `modules/common.nix` (`openssh.authorizedKeys.keys`). Si tu n'as pas de clé ed25519 : `ssh-keygen -t ed25519`.
2. Facultatif mais recommandé : prépare les secrets. Il faut Nix, par exemple sur la distro NixOS-WSL :
   ```bash
   nix develop
   ```
   ```bash
   bash scripts/init-secrets.sh
   ```
   Le script crée `~/.config/sops/age/keys.txt` (**à sauvegarder dans Bitwarden**), remplit `.sops.yaml` et chiffre le hash de ton mot de passe dans `secrets/secrets.yaml`.

   Sans cette étape, le mot de passe initial est `changeme`, à changer avec `passwd`.
3. Commite ton travail (un flake ne voit que les fichiers suivis par Git) :
   ```bash
   git add -A && git commit -m "config"
   ```

## 3. Installer dans la VM

Démarre sur l'ISO, puis :

```bash
sudo -i
```
```bash
nix-shell -p git
```
```bash
git clone <url-du-dépôt> /tmp/cfg
```
Sans remote, copie le dossier : `scp -r ... root@<ip-iso>:/tmp/cfg`, après avoir fait `passwd` dans l'ISO.

Si tu as des secrets, copie aussi `keys.txt` dans l'ISO. Ensuite :

```bash
bash /tmp/cfg/scripts/install.sh nix-desktop-vm
```
```bash
reboot
```

Le script `install.sh` enchaîne :
1. disko : efface, partitionne, formate et monte le disque ;
2. copie de la clé age ;
3. `nixos-install` ;
4. copie du dépôt dans `~/nix-desktop-config`.

Au premier démarrage, connecte-toi sur l'écran de connexion, puis lance :

```bash
bash ~/nix-desktop-config/scripts/test.sh
```

## 4. Au quotidien

Le système se **met à jour tout seul chaque semaine** (paquets, Oh My Zsh…) : le nouveau système est préparé et s'active au **prochain démarrage**. Suivi : `journalctl -u lucas-auto-upgrade`. Lancer tout de suite : `sudo systemctl start lucas-auto-upgrade`.

```bash
cd ~/nix-desktop-config        # alias : cfg
git add -A && nh os switch     # appliquer (alias : rebuild)
nix flake update && git add -A && nh os switch   # mettre à jour les paquets
nix develop .#dfir             # shell forensique (volatility3 : vol)
sops secrets/secrets.yaml      # éditer les secrets (dans nix develop)
```

- **Rollback :** choisir une génération précédente au menu systemd-boot, ou `sudo nixos-rebuild switch --rollback`.
- **Changement de release** (26.05 → 26.11) : modifier les URL `nixos-26.xx` et `release-26.xx`, lancer `nix flake update`, puis `sudo nixos-rebuild boot --flake .` et redémarrer. Ne jamais toucher `system.stateVersion` ni `home.stateVersion`.

### Shell

Oh My Zsh avec tes plugins (git, gitfast, sudo, web-search, autojump, history, jsontools, fzf, aliases, catimg, extract, docker, python, rust, golang, npm, colored-man-pages, copypath, copyfile, z, systemd, ssh-agent, nmap), plus l'autosuggestion, la coloration syntaxique et zsh-completions. `open <fichier>` ouvre n'importe quel fichier avec l'appli par défaut, comme sur macOS.

### Personnaliser powerlevel10k

Ta config est dans `home/p10k.zsh` (mode `awesome-fontconfig` : les polices Awesome Terminal Fonts et Powerline sont installées). Pour la modifier :

```bash
p10k configure
```
```bash
cp ~/.p10k.zsh ~/nix-desktop-config/home/p10k.zsh
```
```bash
rm ~/.p10k.zsh
```
```bash
cfg && git add -A && rebuild
```

Le fichier `home/p10k.zsh` est pris automatiquement s'il existe.

### Bureau KDE Plasma façon macOS

L'écran de connexion (SDDM) et le bureau sont au thème WhiteSur. Le tout est décrit dans `home/plasma.nix` :

| Élément | Équivalent macOS |
|---|---|
| Barre en haut : logo NixOS, **menu global** de l'appli active, icônes système, horloge | barre de menus |
| Dock flottant centré en bas, qui s'efface quand une fenêtre le recouvre | Dock |
| Thème WhiteSur sombre, icônes WhiteSur, curseur macOS, police Inter | apparence |
| Boutons rouge/jaune/vert **à gauche** des fenêtres | feux tricolores |
| Flou et translucidité (barre, dock, menus Kvantum, Ghostty) | effet verre |
| Réduction avec l'effet « lampe magique » | effet Génie |
| Touche Windows (ou `Win+Espace`) : **Vicinae**, lanceur façon Raycast ; `Alt+Espace` : KRunner | Spotlight / Raycast |
| Souris dans le coin haut-gauche : vue d'ensemble des fenêtres | Mission Control |

**Raccourcis** (`Win` = touche Windows) :

| Touches | Action |
|---|---|
| `Win` seule | Vicinae (lanceur) |
| `Win+T` / `Win+C` / `Win+D` / `Win+A` | Ghostty / Brave / Discord / Claude Desktop |
| `Win+↑` | fenêtre maximisée sur l'écran actuel (rappuyer pour revenir) |
| `Win+↓` | réduire la fenêtre |
| `Ctrl+Alt+←` / `→` | bureau précédent / suivant |
| `Ctrl+Alt+↑` (ou `Win+W`, ou coin haut-gauche) | vue d'ensemble (Mission Control) |
| `Win+1…4` / `Win+Maj+1…4` | aller au bureau N / y envoyer la fenêtre |
| `Ctrl+Alt+T` | activer / couper le tuilage automatique (Krohnkite) |
| `Ctrl+N` | nouvelle fenêtre : géré par chaque appli |

**Ghostty** : `Ctrl+Maj+T` nouvel onglet, `Ctrl+Maj+D` séparation horizontale (terminal en dessous), `Ctrl+Maj+R` séparation verticale (terminal à droite).

Pour aller plus loin :
- **Tuilage automatique** (Krohnkite, façon Hyprland) : inactif à chaque ouverture de session, `Ctrl+Alt+T` le bascule.
- **Écrans** : *Paramètres → Affichage et écran* (position, résolution, fréquence, échelle). KDE mémorise une configuration par combinaison d'écrans.
- **Menu global** : il marche avec les applis KDE/Qt et une partie des applis GTK. Les applis Electron (VS Code, Discord, Obsidian…) gardent leur menu dans leur fenêtre.
- Les réglages **déclarés** dans `home/plasma.nix` (thème, barre, dock, effets…) sont réappliqués à chaque rebuild : si tu les changes à la souris, mets aussi la nouvelle valeur dans ce fichier. Tous les autres réglages faits à la souris sont conservés.

### Fonds d'écran animés (Wallpaper Engine)

Il faut **posséder Wallpaper Engine sur Steam** et l'installer (Steam → Bibliothèque) : les deux outils ci-dessous utilisent ses ressources.

**Sous KDE**, le plugin intégré : clic droit sur le bureau → *Configurer le bureau et le fond d'écran* → type de fond **Wallpaper Engine**, puis choisis le dossier Steam et un fond.

Les fonds viennent du Workshop (abonne-toi dans Steam) et arrivent dans `~/.local/share/Steam/steamapps/workshop/content/431960/<id>`.

**Pour tester un fond dans une fenêtre** (sans toucher au bureau) :

```bash
linux-wallpaperengine --window 0x0x1280x720 <id-ou-dossier-du-fond>
```

Les fonds « vidéo » marchent partout ; les fonds « scène » demandent un vrai GPU (lents ou noirs dans une VM sans 3D).

### Logitech, Bluetooth, réseau

- **Solaar** (MX Master 3, MX Keys) démarre avec la session. Il gère l'appairage Bolt/Unifying, la batterie, les boutons et les touches Easy-Switch.
- **Bluetooth** : icône Bluetooth de la barre du haut.
- **Tailscale** : `sudo tailscale up`.
- **OpenVPN** : importe un profil `.ovpn` dans les paramètres réseau.
- **WireGuard** : `wg-quick up <conf>`.

### Gaming

- **Proton-GE** : lance `protonup-qt` et installe GE-Proton. Ensuite, dans Steam : Propriétés du jeu → Compatibilité → GE-Proton.
- **Options de lancement Steam** : `gamemoderun mangohud %command%`.
- **Session « Steam Big Picture »** façon Steam Deck : elle est disponible à l'écran de connexion (Gamescope).

### Claude Desktop (officiel) et Cowork

C'est le paquet `.deb` d'Anthropic (beta Linux), exécuté dans un environnement FHS (`pkgs/claude-desktop`). Il ne se met pas à jour seul. Pour mettre à jour, modifie `version` et `sha256` dans `pkgs/claude-desktop/package.nix` avec les valeurs de l'index :

```bash
curl -s https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages | grep -E '^(Version|SHA256):' | tail -2
```

**Cowork** a besoin de KVM. Le groupe `kvm` et le module `vhost_vsock` sont configurés. Dans la VM VirtualBox, il faut en plus activer la virtualisation imbriquée (VM éteinte) :

```bash
VBoxManage modifyvm "<nom-de-la-VM>" --nested-hw-virt on
```

### Rust, Python, Go…

- **Rust :** `rustup default stable` au premier lancement.
- **Python :** `uv init`, `uv add <paquet>`, `uv run`. Pour un outil : `uv tool install <outil>`.
- **plaso** n'est pas dans nixpkgs. L'alias `plaso` lance l'image Docker officielle :
  ```bash
  plaso log2timeline --storage-file /data/out.plaso /data/image.E01
  ```
- **Exegol :** à installer toi-même. Docker et le GPU dans les conteneurs sont prêts.

### Secrets : ajouter la clé de l'host

Après le premier démarrage, l'host peut déchiffrer avec sa propre clé SSH. Lance :

```bash
nix develop -c bash scripts/add-host-key.sh
```
```bash
git add -A && rebuild
```

`/var/lib/sops-nix/key.txt` (la copie de ta clé perso) peut alors être supprimé.

## 5. Passage à la tour (OS principal)

La tour tourne aujourd'hui sous Kali (Lexar 1 To) avec Windows (2e Lexar 1 To). L'installation **efface** :
- le Lexar Kali, qui devient le disque système ;
- le Lexar Windows et le Kingston 512 Go, qui sont réunis sur `/data` (1,5 To).

Les disques USB (T7 Shield, Toshiba) et le Samsung 256 Go ne sont pas touchés. Les disques sont désignés par leur identifiant stable (`/dev/disk/by-id/…`) dans `hosts/nix-desktop/default.nix`.

### a. Sauvegarder (depuis Kali)

```bash
sudo apt install restic
```
```bash
bash ~/homelab/nixos/nix-desktop-config/scripts/sauvegarde-kali.sh
```

Le script crée un dépôt restic chiffré sur le T7 Shield (`/mnt/2To_lucas/restic-kali`) et y sauvegarde :
- le home, sans les caches ;
- un inventaire : paquets apt, conteneurs et volumes Docker, crontab ;
- les VMs VirtualBox, au choix une par une ;
- les données Windows : Documents, Bureau, Images, Musique, Zotero, plus Téléchargements au choix ;
- les modèles Ollama et les volumes Docker, au choix.

Il termine par une vérification d'intégrité (`restic check`). **Note le mot de passe dans Bitwarden** : sans lui, la sauvegarde est illisible. Tu peux relancer le script autant de fois que tu veux : seules les modifications sont réenvoyées.

### b. Installer

1. Démarre sur l'ISO NixOS 26.05 (clé USB), en **mode UEFI**.
2. Régénère le matériel :
   ```bash
   nixos-generate-config --no-filesystems --show-hardware-config > /tmp/cfg/hosts/nix-desktop/hardware-configuration.nix
   ```
   Garde `hardware.cpu.intel.updateMicrocode = true;`.
3. Lance l'installation :
   ```bash
   sudo bash /tmp/cfg/scripts/install.sh nix-desktop
   ```
   Le script affiche **chaque disque qui sera effacé** (modèle et taille). Vérifie bien la liste, puis tape `OUI`.
4. Après le redémarrage : `nvidia-smi`, `docker run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi`, puis `scripts/test.sh`.

L'extension pack VirtualBox est compilé localement au premier build : c'est long, c'est normal.

### c. Restaurer (sur NixOS)

Branche le T7 (il apparaît sous `/run/media/jobl1n0urs/…`), puis restaure **dans un dossier à part** :

```bash
export RESTIC_REPOSITORY=/run/media/jobl1n0urs/<T7>/restic-kali
```
```bash
restic snapshots
```
```bash
restic restore latest --tag kali-home --target ~/kali
```

Ne restaure jamais directement sur `~` : ta config (zsh, Ghostty, KDE…) est gérée par Nix. Reprends ensuite ce dont tu as besoin depuis `~/kali/home/joblinours/` :
- `.ssh` et `.gnupg`, puis `chmod 700 ~/.ssh ~/.gnupg` ;
- tes dossiers (Documents, Script, Git…) ;
- les profils de navigateurs (`.config/BraveSoftware`, `.mozilla`).

Pour les gros éléments, restaure directement sur `/data` :
- VMs : `restic restore latest --tag vm --target /data/vms` ;
- modèles : `--tag ollama --target /data/modeles`.

## 6. Installer le laptop (`nix-laptop`)

Même socle que la tour (NVIDIA comprise, en mode hybride), sans OpenRGB ni OpenDeck. Réseau en DHCP partout, sauf sur le wifi `Jobl'Internet` où il prend `192.168.1.202` (profil `wifi-statique`).

1. Les **deux SSD internes** sont effacés : `nvme0n1` (système) et `nvme1n1` (`/data`). Le script affiche leurs modèles avant de demander `OUI` : vérifie qu'aucun disque externe n'est dans la liste.
2. Démarre sur l'ISO NixOS 26.05 en **mode UEFI**, connecte le wifi (`nmtui`), puis :
   ```bash
   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/joblinours/NixOS_config/main/scripts/install.sh)" install nix-laptop
   ```
   Le script régénère `hardware-configuration.nix` (réponds `O`), affiche le disque qui sera effacé, puis demande `OUI`.
3. Au premier démarrage : connecte le wifi maison une fois (`nmcli con up wifi-statique --ask`, ou depuis KDE), puis `scripts/test.sh`. Commite le `hardware-configuration.nix` généré.
4. GPU : la GTX 1660 Ti tourne en **PRIME offload**. L'iGPU gère l'écran et la NVIDIA s'éteint quand elle ne sert pas. Pour l'utiliser : `nvidia-offload <appli>`, ou `nvidia-offload %command%` dans les options de lancement Steam. `install.sh` détecte les adresses PCI des deux GPU et remplit `hosts/nix-laptop/prime.nix` (à committer). Vérification : `nvidia-offload glxinfo -B | grep renderer`.

## Points connus

- **VS Code 1.144 :** le paquet nixpkgs 26.05 casse au build (chemin de ripgrep déplacé). Un correctif est en place dans l'overlay (`flake.nix`). Retire-le quand nixpkgs sera corrigé.
- **ArtCraft :** les apps sont en alpha, empaquetées en Nix par `olafkfreund/nix-craftapps` (PhotoCraft, PdfCraft, WordCraft, GridCraft, CADCraft). Le Flatpak OCI officiel échouait : son authentificateur exige une session graphique.
- **VM VirtualBox :** le GPU virtuel n'offre qu'OpenGL 4.1, ce qui donne trois contournements, propres à la VM (`lucas.vm.enable`) :
  - Ghostty (qui exige OpenGL 4.3) tourne en rendu logiciel ;
  - VS Code, Discord, Obsidian, Signal et Brave sont lancés avec `--disable-gpu` ;

  **Recommandé dans VirtualBox : désactiver l'accélération 3D.** Toutes les applis passent alors en rendu logiciel et fonctionnent, ArtCraft compris. En contrepartie, le flou de KDE est désactivé ou lent. Rien de tout ça ne s'applique à la tour (RTX 4060).
- **Absents de nixpkgs 26.05 :**
  - capa : empaqueté depuis le binaire officiel (`pkgs/capa`) ;
  - plaso : Docker ;
  - OpenDeck : Flathub ;
  - neofetch : retiré de nixpkgs, remplacé par `fastfetch` (l'alias `neofetch` le lance).
