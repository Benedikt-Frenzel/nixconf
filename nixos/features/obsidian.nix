{
  flake.nixosModules.obsidian = {
    pkgs,
    config,
    ...
  }: let
    user = config.preferences.user.name;
    home = config.users.users.${user}.home;
    group = config.users.users.${user}.group;
  in {
    environment.systemPackages = [pkgs.obsidian];

    persistance.data.directories = [".config/obsidian"];

    systemd.tmpfiles.rules = [
      "d ${home}/Documents/Private 0700 ${user} ${group} -"
      "d ${home}/Documents/Genealogy 0700 ${user} ${group} -"
    ];
  };
}
