## Taken from Chris Warbo http://chriswarbo.net/git/nix-config.git


# Allow git repos to be used without pre-determined revisions or hashes, in the
# same way we can use `src = ./.`.
#
# For example:
#
# let latestGit = import /path/to/latestGit.nix
#  in stdenv.mkDerivation {
#       name = "My Project";
#       src  = latestGit { url = "http://example.com/project.git"; };
#     }
#
# TODO: This duplicates some functionality of fetchgitrevision; wait for that
# API to settle down, then use it here.

{ cacert, fetchGitHashless, fetchGitPrivateHashless, git, gnused, runCommand, sanitiseName, openssh, writeScript, stdenv }:

with builtins;

{
  latestGit =
    # We need the url, but ref is optional (e.g. if we want a particular branch)
    { url, ref ? "HEAD" }@args:
      with rec {
	# We allow refs to be given in two ways: as a standalone env var...
	key    = "${hashString "sha256" url}_${hashString "sha256" ref}";
	keyRev = getEnv "nix_git_rev_${key}";

	# Or as an entry in a JSON table
	repoRefStr = getEnv "REPO_REFS";
	repoRefs   = if repoRefStr == ""
			then {}
			else fromJSON repoRefStr;

	# Get the commit ID for the given ref in the given repo.
	newRev = import (runCommand
	  "repo-${sanitiseName ref}-${sanitiseName url}"
	  {
	    inherit ref url;

	    # Avoids caching. This is a cheap operation and needs to be up-to-date
	    version = toString currentTime;

	    # Required for SSL
	    GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";

	    buildInputs = [ git gnused ];
	  }
	  ''
	    REV=$(git ls-remote "$url" "$ref") || exit 1

	    printf '"%s"' $(echo "$REV"        |
			    head -n1           |
			    sed -e 's/\s.*//g' ) > "$out"
	  '');

	rev = repoRefs.url or (if keyRev == ""
				  then newRev
				  else keyRev);
      };
      fetchGitHashless (removeAttrs (args // { inherit rev; }) [ "ref" ]);

  latestGitPrivate =
    # We need the url, but ref is optional (e.g. if we want a particular branch)
    { url, ref ? "HEAD" }@args:
      with rec {
	# We allow refs to be given in two ways: as a standalone env var...
	key    = "${hashString "sha256" url}_${hashString "sha256" ref}";
	keyRev = getEnv "nix_git_rev_${key}";

	# Or as an entry in a JSON table
	repoRefStr = getEnv "REPO_REFS";
	repoRefs   = if repoRefStr == ""
			then {}
			else fromJSON repoRefStr;

	# Get the commit ID for the given ref in the given repo.
	newRev = import (runCommand
	  "repo-${sanitiseName ref}-${sanitiseName url}"
	  {
	    inherit ref url;

	    # Avoids caching. This is a cheap operation and needs to be up-to-date
	    version = toString currentTime;

	    # Required for SSL
	    GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";

            SSH_AUTH_SOCK = if (builtins.tryEval <ssh-auth-sock>).success
	      then builtins.toString <ssh-auth-sock>
	      else null;

	    GIT_SSH = writeScript "latestgit-ssh" ''
	      #! ${stdenv.shell}
	        exec -a ssh ${openssh}/bin/ssh -F ${let
	    	sshConfigFile = if (builtins.tryEval <ssh-config-file>).success
	    	  then <ssh-config-file>
	    	  else builtins.trace ''
	    	    Please set your nix-path such that ssh-config-file points to a file that will allow ssh to access private repositories. The builder will not be able to see any running ssh agent sessions unless ssh-auth-sock is also set in the nix-path.

	    	    Note that the config file and any keys it points to must be readable by the build user, which depending on your nix configuration means making it readable by the build-users-group, the user of the running nix-daemon, or the user calling the nix command which started the build. Similarly, if using an ssh agent ssh-auth-sock must point to a socket the build user can access.

	    	    You may need StrictHostKeyChecking=no in the config file. Since ssh will refuse to use a group-readable private key, if using build-users you will likely want to use something like IdentityFile /some/directory/%u/key and have a directory for each build user accessible to that user.
	    	  '' "/var/lib/empty/config";
	      in builtins.toString sshConfigFile} "$@"
	    '';

	    buildInputs = [ git gnused openssh];
	  }
	  ''
	    echo "TEEEST"
	    echo $SSH_AUTH_SOCK
	    cat $GIT_SSH
	    
	    REV=$(git ls-remote "$url" "$ref") || exit 1

	    printf '"%s"' $(echo "$REV"        |
			    head -n1           |
			    sed -e 's/\s.*//g' ) > "$out"
	  '');

	rev = repoRefs.url or (if keyRev == ""
				  then newRev
				  else keyRev);
      };
      fetchGitPrivateHashless (removeAttrs (args // { inherit rev; }) [ "ref" ]);
  
}      
