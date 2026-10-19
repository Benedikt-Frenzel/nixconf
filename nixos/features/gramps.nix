{
  flake.nixosModules.gramps = {pkgs, ...}: {
    environment.systemPackages = [pkgs.gramps];

    persistance.data.directories = [".gramps"];
  };
}
