{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.santiment.ec2-init;
in {

  imports = [
    ./sanbase.nix
    ./projecttransparency.nix
    ./projecttransparency-deployment.nix
  ];
  
  options = {
    santiment.ec2-init.enable = mkOption {
      description = "Set up an Amazon ec2 image";
      default = false;
      type = types.bool;
    };

  };

  config = mkIf cfg.enable {

    ec2.hvm = true;

    # Standard amazon-init has the wrong NIX_PATH. We replace it with
    # our own script below
    systemd.services.amazon-init.enable = false;

    # Set Nix path. The /etc/nixos/secrets/ folder is contained in our
    # generic AMI image
    nix.nixPath = [
      "nixpkgs=https://github.com/santiment/nixpkgs/archive/${pkgs.deploymentEnvironment}.tar.gz"
      "nixos-config=/etc/nixos/configuration.nix"
      "ssh-config-file=/etc/nixos/secrets/sshconfig"
    ];

    /* Set-up autoupgrade */
    environment.systemPackages = [
      pkgs.gzip
    ];
    
    system.autoUpgrade = {
      /* Enable for the stage and production environments */
      enable = (
        pkgs.deploymentEnvironment == "stage" ||
        pkgs.deploymentEnvironment == "production"
      );

      flags = concatMap (x: ["-I" x]) config.nix.nixPath;


      /* Upgrade the production environment once a day at 00:00:00 UTC.
         Upgrade all other environments once every 10 minutes
      */
      dates = if pkgs.deploymentEnvironment == "production"
        then
          "daily UTC"
        else
          "*:00/10:00";
    };

    systemd.services.nixos-upgrade.path = [pkgs.gzip];

    /* Initialize system from user-data on startup */
    systemd.services.amazon-custom-init = {
      description = "Initialize system from EC2 userdata on startup";

      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      requires = [ "network-online.target" ];

      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig = {
	Type = "oneshot";
	RemainAfterExit = true;
      };

      environment = {
        NIX_PATH = concatStringsSep ":" config.nix.nixPath;
      };

      path = [pkgs.gnutar pkgs.gzip pkgs.xz.bin];

      script = ''
	#!${pkgs.stdenv.shell} -eu

	echo "attempting to fetch configuration from EC2 user data..."

	export HOME=/root
	export PATH=${pkgs.lib.makeBinPath [ config.nix.package pkgs.systemd pkgs.gnugrep pkgs.gnused config.system.build.nixos-rebuild]}:$PATH

	userData=/etc/ec2-metadata/user-data

	if [ -s "$userData" ]; then
	  # If the user-data looks like it could be a nix expression,
	  # copy it over. Also, look for a magic three-hash comment and set
	  # that as the channel.
	  if sed '/^\(#\|SSH_HOST_.*\)/d' < "$userData" | grep -q '\S'; then
	    channels="$(grep '^###' "$userData" | sed 's|###\s*||')"
	    printf "%s" "$channels" | while read channel; do
	      echo "writing channel: $channel"
	    done

	    if [[ -n "$channels" ]]; then
	      printf "%s" "$channels" > /root/.nix-channels
	      nix-channel --update
	    fi

	    echo "setting configuration from EC2 user data"
	    cp "$userData" /etc/nixos/configuration.nix
	  else
	    echo "user data does not appear to be a Nix expression; ignoring"
	    exit
	  fi
	else
	  echo "no user data is available"
	  exit
	fi

	nixos-rebuild switch
      '';

    };
    
  };
 
}

