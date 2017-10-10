{pkgs, deploymentEnvironment ? pkgs.deploymentEnvironment}:
let
  update = self: super:
    rec {
      callPackage = super.newScope self;

      sanitiseName = callPackage ./lib/sanitiseName.nix {};
      fetchGitHashless = (callPackage ./lib/fetchGitHashless.nix {}).fetchGitHashless;
      fetchGitPrivateHashless = (callPackage ./lib/fetchGitHashless.nix {}).fetchGitPrivateHashless;
      latestGit = (callPackage ./lib/latestGit.nix {}).latestGit;
      latestGitPrivate = (callPackage ./lib/latestGit.nix {}).latestGitPrivate;

      sanbase = callPackage (latestGit {
        url =  "https://github.com/santiment/sanbase.git";
	ref = "refs/heads/${deploymentEnvironment}";
      }) {};

      projecttransparency = callPackage (latestGitPrivate {
        url = "git@github.com:santiment/projecttransparency.org.git";
	ref = "refs/heads/${deploymentEnvironment}";
      }) {};
    };

  result = update result pkgs;

in result
