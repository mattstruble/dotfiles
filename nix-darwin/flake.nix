{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai-agents.url = "github:mattstruble/nix-ai-agents";
    agent-sandbox.url = "github:mattstruble/agent-sandbox";

    beads = {
      url = "github:gastownhall/beads";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    skills-mattstruble = {
      url = "github:mattstruble/skills";
      flake = false;
    };

    ebook-mcp = {
      url = "github:onebirdrocks/ebook-mcp";
      flake = false;
    };

    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    rtk = {
      url = "github:rtk-ai/rtk";
      flake = false;
    };

    determinate.url = "github:DeterminateSystems/determinate";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
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
                overlays = [
                  (final: prev: {
                    beads = inputs.beads.packages.${system}.default;
                  })
                ];
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
                    users = import ./hosts/${hostname}/home.nix { inherit inputs; };
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
