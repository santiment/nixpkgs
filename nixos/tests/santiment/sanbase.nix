import ../make-test.nix {

  nodes = {
    server = {config, pkgs, ...}:
      {
        virtualisation.memorySize = 1024;
        services.santiment.sanbase.enable = true;

      };

    client = {config, pkgs, ...}:{};
  };

  testScript =
    ''
      $server->start;
      $client->start;

      $server->waitForUnit("multi-user.target");
      $client->waitForUnit("network.target");

      subtest "Return error when no DB connection found", sub {
        $client->succeed("test `curl -L -s -o /dev/null -I -w \"%{http_code}\" http://server/cashflow/` -ge \"500\" ");
      };
    '';

}
