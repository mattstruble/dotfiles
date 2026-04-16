{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arkenfox-userjs.url = "github:petrkozorezov/arkenfox-userjs-nix";
    ai-agents.url = "github:mattstruble/nix-ai-agents";
    agent-sandbox.url = "github:mattstruble/agent-sandbox";

    skills-mattpocock = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    skills-mattstruble = {
      url = "github:mattstruble/skills";
      flake = false;
    };

    skills-superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };

    ebook-mcp = {
      url = "github:onebirdrocks/ebook-mcp";
      flake = false;
    };

    determinate.url = "github:DeterminateSystems/determinate";

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
                determinate.darwinModules.default
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
          lm-mstruble = configure "lm-mstruble.system" "aarch64-darwin";
        };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = {
        "MacStruble" = self.darwinConfigurations."MacStruble".pkgs;
        lm-mstruble = self.darwinConfigurations."lm-mstruble".pkgs;
      };
    };

}
