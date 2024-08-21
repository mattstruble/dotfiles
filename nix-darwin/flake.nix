{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    with inputs; rec {
      darwinConfigurations =
        let
          userName = builtins.getEnv "USER";
          configure = arch: system:
            darwin.lib.darwinSystem {
              pkgs = import nixpkgs {
                inherit system;
                config = {
                  allowUnfree = true;
                  allowBroken = false;
                  allowInsecure = false;
                  allowUnsupportedSystem = false;
                };
              };

              inherit system;
              specialArgs = { inherit inputs; };
              modules = [
                ./darwin.nix
                home-manager.darwinModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = true;
                    users."${userName}" = import ./home.nix;
                    extraSpecialArgs = { inherit inputs; };
                  };
                }
              ];
            };
        in
        {
          arm = configure "arm" "aarch64-darwin";
          i386 = configure "i386" "x86_64-darwin";
        };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."arm".pkgs;
    };

}
