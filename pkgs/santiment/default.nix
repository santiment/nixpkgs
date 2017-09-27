{pkgs, deploymentEnvironment ? pkgs.deploymentEnvironment}:
let
  update = self: super:
    rec {
      callPackage = super.newScope self;

      sanitiseName = callPackage ./lib/sanitiseName.nix {};
      fetchGitHashless = callPackage ./lib/fetchGitHashless.nix {};
      latestGit = callPackage ./lib/latestGit.nix {};

      sanbase = latestGit {
        url =  "https://github.com/santiment/sanbase.git";
	ref = "refs/heads/${deploymentEnvironment}";
      };
    };

  result = update result pkgs;

in result
