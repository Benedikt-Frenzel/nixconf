{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    identity = {
      name = "Benedikt Frenzel";
      email = "git@bfr.sh";
    };
    # Public half of the SSH key in the host 1Password vault (geeky#ben).
    signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9tV5OCfsjlyLiPOwQZsx6NmK6D9KCD8iGmUnQF9/Bz geeky";
    allowedSigners = pkgs.writeText "allowed_signers" ''
      ${identity.email} namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9tV5OCfsjlyLiPOwQZsx6NmK6D9KCD8iGmUnQF9/Bz
    '';
    # programs._1password-gui installs this. Absolute so the wrapper PATH still finds it.
    signer = "/run/current-system/sw/bin/op-ssh-sign";
  in {
    packages.git = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.git;
      env = {
        GIT_AUTHOR_NAME = identity.name;
        GIT_AUTHOR_EMAIL = identity.email;
        GIT_COMMITTER_NAME = identity.name;
        GIT_COMMITTER_EMAIL = identity.email;

        GIT_CONFIG_COUNT = "6";
        GIT_CONFIG_KEY_0 = "gpg.format";
        GIT_CONFIG_VALUE_0 = "ssh";
        GIT_CONFIG_KEY_1 = "user.signingkey";
        GIT_CONFIG_VALUE_1 = signingKey;
        GIT_CONFIG_KEY_2 = "gpg.ssh.program";
        GIT_CONFIG_VALUE_2 = signer;
        GIT_CONFIG_KEY_3 = "gpg.ssh.allowedSignersFile";
        GIT_CONFIG_VALUE_3 = allowedSigners;
        GIT_CONFIG_KEY_4 = "commit.gpgsign";
        GIT_CONFIG_VALUE_4 = "true";
        GIT_CONFIG_KEY_5 = "tag.gpgsign";
        GIT_CONFIG_VALUE_5 = "true";
      };
    };
  };
}
