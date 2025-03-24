{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
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

  outputs =
    inputs: with inputs; {
      darwinConfigurations =
        let
          userName = builtins.getEnv "USER";
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
                nix-homebrew.darwinModules.nix-homebrew
                {
                  nix-homebrew = {
                    enable = false;
                    user = "${userName}";
                    autoMigrate = true;
                  };
                }
                ./darwin.nix
                home-manager.darwinModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = true;
                    backupFileExtension = "backup";
                    users."${userName}" = import ./home.nix;
                    extraSpecialArgs = {
                      inherit hostname inputs;
                    };
                  };
                }
              ];
            };
        in
        {
          MacStruble = configure "MacStruble" "x86_64-darwin";
          APKQTFWJ12ED96 = configure "APKQTFWJ12ED96" "aarch64-darwin";
        };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = {
        "MacStruble" = self.darwinConfigurations."MacStruble".pkgs;
        "APKQTFWJ12ED96" = self.darwinConfigurations."APKQTFWJ12ED96".pkgs;
      };
    };

}
