{
  description = "Darwin configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    # beads only: its dependencies can require a newer Go than nixpkgs-weekly ships.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
    # No nixpkgs follows: keeps hashes matching cache.numtide.com.
    llm-agents.url = "github:numtide/llm-agents.nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nono = {
      url = "github:nolabs-ai/nono";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned to a rev, not a branch. bd refuses to open a database whose schema
    # is ahead of its own, and bringing a store up to date is one-way, so an
    # unpinned input lets a routine flake update leave every tracker unreadable
    # (it did: stores were at v67, the binary moved to v74). To bump: back up
    # ~/.local/share/beads-dolt, update this rev, then `bd migrate schema`.
    beads = {
      url = "github:gastownhall/beads/1337d99d5979646d0f7871afad4bce988f24183f";
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

    obsidian-extensions = {
      url = "github:karaolidis/nix-obsidian-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
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
                    # Node build: pi-subagents imports the pi SDK package from disk, which the
                    # Bun-compiled binary does not ship.
                    pi = inputs.llm-agents.packages.${system}.pi.override { useBun = false; };
                  })
                  (final: prev: {
                    # beads' own postPatch lowers go.mod to the toolchain, but its dependencies
                    # (dolt) can still need a newer Go than nixpkgs-weekly, so build it on unstable.
                    beads = (import inputs.nixpkgs-unstable {
                      inherit system;
                      overlays = [ inputs.beads.overlays.default ];
                    }).beads;
                  })
                  (final: prev: {
                    # bd refuses shared Dolt servers older than 2.6.0 (its embedded engine pin);
                    # nixpkgs lags. Pinned to the tag bd's go.mod embeds; bump alongside beads.
                    # dolt 2.6 needs Go 1.27, so build on unstable.
                    dolt =
                      let
                        unstable = import inputs.nixpkgs-unstable { inherit system; };
                      in
                      (unstable.dolt.override { buildGoModule = unstable.buildGo127Module; }).overrideAttrs
                        (old: rec {
                          version = "2.6.0";
                          src = unstable.fetchFromGitHub {
                            owner = "dolthub";
                            repo = "dolt";
                            tag = "v${version}";
                            hash = "sha256-eljRYO6YyhFaxmxuPifVxgtXYG4f8iysJFwBJVbuEoo=";
                          };
                          vendorHash = "sha256-Hr4bOkPGUQqO07PAey7GWCJ/1zBC9hIj4xzJGLh44jY=";
                        });
                  })
                  (final: prev: {
                    # ponytail: recode 3.7.16 breaks on macOS iconv (duplicate aliases → fortune segfaults);
                    # 3.7.17 has the upstream workaround. Drop once nixpkgs ships >= 3.7.17.
                    recode = prev.recode.overrideAttrs (old: rec {
                      version = "3.7.17";
                      src = prev.fetchurl {
                        url = "https://github.com/rrthomas/recode/releases/download/v${version}/recode-${version}.tar.gz";
                        hash = "sha256-Gwrr5yg7ef9GvAoG7iH69ltNCzBGMsvIVXIcJVg9jqM=";
                      };
                    });
                  })
                  inputs.obsidian-extensions.overlays.default
                  (final: prev: {
                    obsidian = prev.obsidian.overrideAttrs (old: {
                      unpackPhase = ''
                        runHook preUnpack
                        unpackFile "$src"
                        if [ ! -d "Obsidian.app" ]; then
                          mv Obsidian*/Obsidian.app .
                        fi
                        # installPhase copies Obsidian.app relative to sourceRoot.
                        sourceRoot="."
                        chmod -R u+r Obsidian.app
                        runHook postUnpack
                      '';
                    });
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
                (
                  { pkgs, ... }:
                  let
                    hmBackup = pkgs.writeShellScript "hm-backup" ''mv -f "$1" "$1.backup"'';
                  in
                  {
                    home-manager = {
                      useGlobalPkgs = true;
                      backupCommand = "${hmBackup}";
                      users = import ./hosts/${hostname}/home.nix { inherit inputs; };
                      extraSpecialArgs = {
                        inherit hostname inputs;
                      };
                    };
                  }
                )
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
