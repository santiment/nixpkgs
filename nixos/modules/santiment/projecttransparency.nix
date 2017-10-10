{ config, lib, pkgs, ... }:
with lib;
  let
    cfg = config.services.santiment.projecttransparency;
    fcgiSocket = "/run/phpfpm/nginx";
    user = "www";
    group = "www";
    uid = 1666;
    gid = 1666;
    rootFolder = "${cfg.package}";
  in  
  {

    options.services.santiment.projecttransparency = {
      enable = mkOption {
        description = "Whether to enable the projecttransparency website";
	default = false;
	type = types.bool;
      };

      environment = mkOption {
        description = "Deployment environment";
	default = pkgs.deploymentEnvironment;
	type = types.string;
      };

      package = mkOption {
        description = "Default projecttransparency package";
	default = pkgs.santiment.projecttransparency;
	type = types.package;
      };

      pg = {
        host = mkOption {
	  description = "URL for Postgres host";
	  default = "localhost";
	  type = types.string;
	};

	username = mkOption {
	  description = "Postgres username";
	  default = "sanbase";
	  type = types.string;
	};

	password = mkOption {
	  description = "Postgres password";
	  default = "sanbase";
	  type = types.string;
	};

	database = mkOption {
	  description = "Postgres database";
	  default = "postgres";
	  type = types.string;
	};
	
      };
    };

    config = mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = [22 80 443 ];
      networking.firewall.allowedUDPPorts = [22 80 443 ];

      users.extraUsers."${user}" = {
	isNormalUser = true;
	useDefaultShell = true;
	uid = uid;
	group = group;
	createHome = true;
      };

    

      # environment.systemPackages = with pkgs; [
      #   apacheHttpd
      # ];


      users.extraGroups."${group}".gid = gid;

      services.phpfpm.poolConfigs.nginx = ''
	listen = ${fcgiSocket}
	listen.owner = ${user}
	listen.group = ${group}
	listen.mode = 0660
	user = ${user}
	pm = ondemand
	pm.max_children = 2
	catch_workers_output = true
	env[DB_SERVER] = ${cfg.pg.host}
	env[DB_DATABASE] =  ${cfg.pg.database}
	env[DB_USER] = ${cfg.pg.username}
	env[DB_PASSWORD] = ${cfg.pg.password}
      '';

      services.nginx = {
	enable = true;
	recommendedOptimisation = true;
	recommendedProxySettings = true;
	recommendedGzipSettings = true;
	recommendedTlsSettings = true;      
	user = user;
	group = group;

	# commonHttpConfig = ''
	#   index index.php index.html index.htm;
	# '';


	virtualHosts = {
	  "projecttransparency.org" = {
	    default = true;
	    root = "${rootFolder}/public";

	    # extraConfig = ''
	    #   auth_basic "Access restricted";
	    #   auth_basic_user_file ${rootFolder}/.htpasswd;
	    # '';

	  locations."~ ^.+\.php(/|$)".extraConfig = ''
	    fastcgi_pass php_projtrans_fcgi;
	    fastcgi_split_path_info ^(.+\.php)(/.*)$;
	    include ${pkgs.nginx}/conf/fastcgi_params;
	    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	    fastcgi_param DOCUMENT_ROOT $document_root;
	    fastcgi_param QUERY_STRING $query_string;
	  '';


	  };
	};

	appendHttpConfig = ''
	  upstream php_projtrans_fcgi {
	    server unix:${fcgiSocket};
	  }

	  index index.php index.html index.htm;

	'';

      };


      # Update wallets and market cap every 5 minutes
      systemd.timers.dataUpdate = {
	description = "Data update timer";

	wantedBy = ["multi-user.target"];
	after = [ "network.target" "local-fs.target" "remote-fs.target"];
	timerConfig = {
	  OnBootSec = 60;
	  OnUnitActiveSec = 300;
	  Unit = "update.service";
	};
      };

      systemd.services.update = {
	description = "Data update service";
	serviceConfig = {
	  User = "${user}";
	  WorkingDirectory = "${rootFolder}";
	};

	path = [ pkgs.php ];

	script = ''
	cd scripts
	php update_wallet.php
	php cmm.php
	'';
      };

      # The NixOS release to be compatible with for stateful data such as databases.
      system.stateVersion = "17.09";
    };

  }
