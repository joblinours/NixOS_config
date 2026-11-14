# Capteurs et ventilateurs (tous les hosts) : lm_sensors + Fan Control (Flatpak).
{ pkgs, ... }:
{
  # `sensors` / `sudo sensors-detect`. ⚠ Sur NixOS, sensors-detect ne peut pas
  # écrire /etc/modules : ajouter les modules qu'il propose (puce Super I/O de la
  # carte mère, ex. "nct6775" ou "it87") dans boot.kernelModules du host,
  # sinon les ventilateurs n'apparaissent pas.
  environment.systemPackages = [ pkgs.lm_sensors ];

  # Fan Control : pilotage des ventilateurs
  services.flatpak.packages = [
    {
      appId = "io.github.wiiznokes.fan-control";
      origin = "flathub";
    }
  ];

  # Fan Control doit pouvoir écrire les consignes PWM des ventilateurs.
  # Règle officielle (res/linux/60-fan-control.rules), chemins adaptés à NixOS.
  services.udev.extraRules = ''
    SUBSYSTEM=="hwmon", RUN+="${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/chmod a+w /sys%p/pwm* || true'"
  '';
}
