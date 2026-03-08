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
    ai-skills.url = "github:mattstruble/nix-ai-skills";

    skills-infra = {
      url = "github:tylertitsworth/skills";
      flake = false;
    };

    skills-anthropic = {
      url = "github:anthropics/skills";
      flake = false;
    };

    skills-nix = {
      url = "github:shakhzodkudratov/nixos-and-flakes-skill/c9a423b2af834633e6ef714de603fe73e6f0b195";
      flake = false;
    };

    skills-mine = {
      url = "github:mattstruble/skills";
      flake = false;
    };

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
          lm-mstruble = configure "lm-mstruble.system" "aarch64-darwin";
        };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = {
        "MacStruble" = self.darwinConfigurations."MacStruble".pkgs;
        "APKQTFWJ12ED96" = self.darwinConfigurations."APKQTFWJ12ED96".pkgs;
        lm-mstruble = self.darwinConfigurations."lm-mstruble".pkgs;
      };
    };

}
