{ pkgs, ... }:
{
  # ── Pare-feu : seul SSH entre ─────────────────────────────────────
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # ── SSH : clé uniquement ──────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ── Antivirus ─────────────────────────────────────────────────────
  services.clamav = {
    daemon.enable = true; # clamd (clamdscan)
    updater.enable = true; # freshclam
  };
  environment.systemPackages = [ pkgs.clamav ]; # clamscan, clamdscan, freshclam
}
