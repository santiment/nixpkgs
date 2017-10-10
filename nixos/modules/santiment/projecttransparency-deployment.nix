{config, lib, pkgs, ...}:
with lib;
let
  envfile = import /etc/nixos/env.nix;
in
{
  options.services.santiment.projecttransparency-deployment = {
    enable = mkOption {
      description = "Enable projecttransparency with config from /etc/nixos/env";
      default = false;
      type = types.bool;
    };
  };

  config = mkIf config.services.santiment.projecttransparency.enable {

    services.santiment.projecttransparency = {
      enable = true;
      pg = {
        host = envfile.host;
	database = envfile.database;
	username = envfile.username;
	password = envfile.password;
      };
    };
  };
}
