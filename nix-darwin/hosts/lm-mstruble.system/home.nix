let
  userName = import ./username.nix;
  home = "/Users/${userName}";
  ca-bundle_path = "/etc/ssl/certs";
  ca-bundle_crt = "${ca-bundle_path}/ca-certificates.crt";
  lila-bundle_crt = "${ca-bundle_path}/rootca.firewall.lila.pem";
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

    home = {
      sessionVariables = {
        AWS_CA_BUNDLE = "${lila-bundle_crt}";
        REQUESTS_CA_BUNDLE = "${ca-bundle_crt}";
        NODE_EXTRA_CA_CERTS = "${ca-bundle_crt}";
        SSL_CERT_FILE = "${ca-bundle_crt}";
        CURL_CA_BUNDLE = "${ca-bundle_crt}";
        PIP_CERT = "${ca-bundle_crt}";
      };
    };

    programs = {
      git = {
        settings = {
          user = {
            name = "Matt Struble";
            email = "mstruble@lila.ai";
          };
          github.user = "mstruble-lila";
        };
      };
    };
  };
}
