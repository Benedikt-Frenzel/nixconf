{
  flake.nixosModules.opensnitch = {
    pkgs,
    config,
    lib,
    ...
  }: {
    services.opensnitch = {
      enable = true;
      # Do not break networking before login or while the UI is unavailable.
      # With the UI connected, new applications still prompt for a decision.
      settings = {
        DefaultAction = "allow";
        DefaultDuration = "once";
        InterceptUnknown = false;
      };
    };

    environment.systemPackages = [pkgs.opensnitch-ui];

    systemd.user.services.opensnitch-ui = {
      description = "OpenSnitch application firewall UI";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      unitConfig.ConditionUser = config.preferences.user.name;
      serviceConfig = {
        ExecStart = lib.getExe pkgs.opensnitch-ui;
        Restart = "on-failure";
        RestartSec = 3;
      };
    };

    persistance.directories = ["/var/lib/opensnitch"];
    persistance.data.directories = [".config/opensnitch"];
  };
}
