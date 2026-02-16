let
  userName = import ./username.nix;
  ca-bundle_path = "/etc/ssl/certs";
  ca-bundle_crt = "${ca-bundle_path}/ca-certificates.crt";
in
{
  "${userName}" = {
    imports = [
      ../../profiles/macos.nix
      ../../home.nix
    ];
    _module.args = {
      ca-bundle_path = ca-bundle_path;
      ca-bundle_crt = ca-bundle_crt;
    };
    programs = {
      git = {
        settings = {
          user = {
            name = "Matt Struble";
            email = "4325029+mattstruble@users.noreply.github.com";
          };
          github.user = "mattstruble";
        };
      };
    };
  };
}
