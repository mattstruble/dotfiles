let
  userName = import ./username.nix;
in
{
  "${userName}" = {
    imports = [
      ../../profiles/macos.nix
      ../../home.nix
    ];
    programs = {
      git = {
        userName = "Matt Struble";
        userEmail = "4325029+mattstruble@users.noreply.github.com";
        extraConfig = {
          github.user = "mattstruble";
        };
      };
    };
  };
}
