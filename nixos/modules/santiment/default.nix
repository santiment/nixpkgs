{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.santiment.ec2-init;
in {

  imports = [ ./sanbase.nix ];
  
  options = {
    santiment.ec2-init.enable = mkOption {
      description = "Set up an Amazon ec2 image";
      default = false;
      type = types.bool;
    };

  };

  config = mkIf cfg.enable {
    ec2.hvm = true;
    nix.nixPath = [
      "nixpkgs=https://github.com/santiment/nixpkgs/archive/${pkgs.deploymentEnvironment}.tar.gz"
      "nixos-config=/etc/nixos/configuration.nix"
    ];
    
  };
 
}

