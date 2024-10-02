{
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
}
