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
        NODE_EXTRA_CA_CERTS = "${home}/.ssl-cert/Nike-Root-Authority-NG.pem";
        REQUESTS_CA_BUNDLE = "${home}/.ssl-cert/Nike-Root-Authority-NG.pem";
        SSL_CERT_FILE = "${home}/.ssl-cert/Nike-Root-Authority-NG.pem";
      };
    };
    programs = {
      git = {
        userName = "Matt Struble";
        userEmail = "matt.struble@nike.com";
        extraConfig = {
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
