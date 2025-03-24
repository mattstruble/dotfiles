{
  imports = [ ../../profiles/macos.nix ];
  programs = {
    git = {
      userName = "Matt Struble";
      userEmail = "4325029+mattstruble@users.noreply.github.com";
      extraConfig = {
        github.user = "mattstruble";
      };
    };
  };
}
