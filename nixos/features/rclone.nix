{
  flake.nixosModules.rclone = {
    pkgs,
    lib,
    config,
    ...
  }: let
    user = config.preferences.user.name;
    home = config.users.users.${user}.home;
    group = config.users.users.${user}.group;

    hochzeit = "${home}/Documents/Hochzeit";
    protonRemote = "protondrive:Hochzeit";
    gdriveRemote = "gdrive:wir/Hochzeit";
    gdriveMount = "${home}/GDrive";

    # bisync hashes the filter file and refuses to run after edits until the
    # next --resync, and it writes that hash next to the file -- so it must
    # live outside the read-only store. The script refreshes it from this
    # store copy before every run.
    bisyncFilters = pkgs.writeText "hochzeit-bisync-filters" ''
      - /.stfolder/
      - ~syncthing~*
      - .syncthing.*.tmp
      - ~$*
      - .DS_Store
      - Thumbs.db
    '';
    filterFile = "${home}/.config/rclone/hochzeit-bisync-filters.txt";

    # Unattended-setup recommendation from https://rclone.org/bisync/#resync.
    # On conflicts the newer file wins and the loser is kept, e.g. as
    # file.txt.conflict1 (default --conflict-loser num).
    bisyncFlags = [
      "--filters-file=${filterFile}"
      "--resilient"
      "--recover"
      "--max-lock 2m"
      "--conflict-resolve newer"
      "-v"
    ];

    hochzeitSync = pkgs.writeShellApplication {
      name = "hochzeit-sync";
      runtimeInputs = [pkgs.rclone pkgs.coreutils];
      text = ''
        # Refresh the filter file from the store; bisync stores its hash
        # next to it and aborts after content changes until the next --resync.
        install -D -m 0644 '${bisyncFilters}' '${filterFile}'

        # Extra flags pass through to both runs, e.g. --dry-run or --resync.
        status=0

        echo ">>> bisync ${hochzeit} <-> ${protonRemote}"
        rclone bisync "${hochzeit}" "${protonRemote}" \
          ${lib.concatStringsSep " " bisyncFlags} \
          "$@" || status=1

        echo ">>> bisync ${hochzeit} <-> ${gdriveRemote}"
        rclone bisync "${hochzeit}" "${gdriveRemote}" \
          ${lib.concatStringsSep " " bisyncFlags} \
          --drive-skip-gdocs \
          "$@" || status=1

        exit "$status"
      '';
    };
  in {
    # rclone 1.75 ships the protondrive backend, so plain rclone doubles as
    # the Proton Drive and Google Drive CLI.
    environment.systemPackages = [pkgs.rclone hochzeitSync];

    persistance.data.directories = [
      # OAuth tokens and obscured Proton credentials
      ".config/rclone"
      # bisync keeps its listing snapshots here; losing them forces a --resync
      ".cache/rclone"
    ];

    systemd.tmpfiles.rules = [
      "d ${hochzeit} 0700 ${user} ${group} -"
      "d ${gdriveMount} 0700 ${user} ${group} -"
    ];

    systemd.services.rclone-mount-gdrive = {
      description = "Mount Google Drive via rclone at ${gdriveMount}";
      documentation = ["https://rclone.org/commands/rclone_mount/"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      # Stay inactive until `rclone config` created the remotes.
      unitConfig.ConditionPathExists = "${home}/.config/rclone/rclone.conf";
      serviceConfig = {
        User = user;
        Group = group;
        Type = "notify";
        # FUSE needs the setuid fusermount3 from /run/wrappers/bin; the
        # plain store copy that rclone appends to PATH is not setuid.
        Environment = "PATH=/run/wrappers/bin";
        ExecStart = "${lib.getExe pkgs.rclone} mount gdrive: ${gdriveMount} --vfs-cache-mode writes";
        # Remove stale mounts after crashes; "-" ignores clean unmounts.
        ExecStopPost = "-/run/wrappers/bin/fusermount3 -u ${gdriveMount}";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    systemd.services.hochzeit-sync = {
      description = "bisync ${hochzeit} with Proton Drive and Google Drive";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      unitConfig.ConditionPathExists = "${home}/.config/rclone/rclone.conf";
      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = group;
        ExecStart = lib.getExe hochzeitSync;
      };
    };

    systemd.timers.hochzeit-sync = {
      description = "Hourly cloud sync for ${hochzeit}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
