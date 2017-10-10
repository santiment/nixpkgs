## Taken from Chris Warbo, http://chriswarbo.net/git/nix-config.git

# Like fetchgit, but doesn't check against an expected hash. Useful if the
# commit ID is generated dynamically.
{ fetchgit, fetchgitPrivate, stdenv }:

with builtins;
let
   x = fetcher:
     args: stdenv.lib.overrideDerivation
	     # Use a dummy hash, to appease fetchgit's assertions
	     (fetcher (args // { sha256 = hashString "sha256" args.url; }))

	     # Remove the hash-checking
	     (old: {
	       outputHash     = null;
	       outputHashAlgo = null;
	       outputHashMode = null;
	       sha256         = null;
	     });
in {
  fetchGitHashless = x fetchgit;
  fetchGitPrivateHashless = x fetchgitPrivate;
}
	    

	     
