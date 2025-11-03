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
