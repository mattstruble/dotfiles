let
  userName = import ./username.nix;
  home = "/Users/${userName}";
in
{
  "${userName}" = {
    imports = [
      ../../profiles/macos.nix
      ../../home.nix
    ];
    home = {
      sessionVariables = {
        OBSIDIAN_VAULT = "${home}/Library/CloudStorage/Box-Box/Obsidian/Vault";
        NODE_EXTRA_CA_CERTS = "${home}/.ssl-cert/NikeRootCA-base64.pem";
        REQUESTS_CA_BUNDLE = "${home}/.ssl-cert/NikeRootCA-base64.pem";
        SSL_CERT_FILE = "${home}/.ssl-cert/NikeRootCA-base64.pem";
        CURL_CA_BUNDLE = "${home}/.ssl-cert/NikeRootCA-base64.pem";
      };
    };
    programs = {
      git = {
        settings = {
          user = {
            name = "Matt Struble";
            email = "matt.struble@nike.com";
          };
          github.user = "mstru3_nike";
        };
      };
      zsh = {
        shellAliases = {
          gimme-aws-creds = "gimme-aws-creds --mfa-code `op item get nikecloud.com --otp`";
        };
      };
    };
  };
}
