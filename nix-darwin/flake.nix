{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arkenfox-userjs.url = "github:petrkozorezov/arkenfox-userjs-nix";
  };

  outputs =
    inputs: with inputs; {
      darwinConfigurations =
        let
          configure =
            hostname: system:
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
              specialArgs = {
                inherit hostname inputs;
              };
              modules = [
                ./darwin.nix
                home-manager.darwinModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = true;
                    backupFileExtension = "backup";
                    users = import ./hosts/${hostname}/home.nix;
                    extraSpecialArgs = {
                      inherit hostname inputs;
                    };
                  };
                }
              ];
            };
        in
        {
          MacStruble = configure "MacStruble" "aarch64-darwin";
          APKQTFWJ12ED96 = configure "APKQTFWJ12ED96" "aarch64-darwin";
        };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = {
        "MacStruble" = self.darwinConfigurations."MacStruble".pkgs;
        "APKQTFWJ12ED96" = self.darwinConfigurations."APKQTFWJ12ED96".pkgs;
      };
    };

}
