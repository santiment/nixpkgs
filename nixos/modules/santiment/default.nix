{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.santiment.ec2-init;
  depenv = builtins.readFile config.santiment.deploymentEnvironmentPath;
in
{

  options = {
    santiment.ec2-init.enable = mkOption {
      description = "Set up an Amazon ec2 image";
      default = false;
      type = types.bool;
    };

    santiment.deploymentEnvironmentPath = mkOption {
      description = "Path to file containing the branch that needs to be tracked";
      default = /etc/nixos/deployment_environment;
      type = types.path;
    };
  };

  config = mkIf cfg.enable {
    ec2.hvm = true;
    nix.nixPath = [
      "nixpkgs=https://github.com/santiment/nixpkgs/archive/${depenv}.tag.gz"
      "nixos-config=/etc/nixos/configuration.nix"
    ];
    
  };
 
}
