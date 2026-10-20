{
  flake.nixosModules.fwupd = {
    # Firmware updates via LVFS, e.g. for the Dell WD19 dock.
    # Lanzaboote signs the fwupd EFI binary for capsule updates on
    # reboot, so this stays compatible with Secure Boot.
    services.fwupd.enable = true;

    # Daemon state and downloaded update metadata.
    persistance.directories = ["/var/lib/fwupd"];
  };
}
