{
  description = "zig template";

  nixConfig = {
    extra-substituters = [
      "https://nix.trev.zip"
    ];
    extra-trusted-public-keys = [
      "trev:I39N/EsnHkvfmsbx8RUW+ia5dOzojTQNCTzKYij1chU="
    ];
  };

  inputs = {
    systems.url = "github:spotdemo4/systems";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    trevpkgs = {
      url = "github:spotdemo4/trevpkgs";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      trevpkgs,
      ...
    }:
    trevpkgs.libs.mkFlake (
      system: pkgs: {

        # nix develop [#...]
        devShells = {
          default = pkgs.mkShell {
            shellHook = pkgs.shellhook.ref;
            packages = with pkgs; [
              # zig
              zig
              zls
              lldb

              # lint
              nixd
              nil

              # format
              nixfmt
              oxfmt
              treefmt

              # util
              bumper
            ];
          };

          bump = pkgs.mkShell {
            packages = with pkgs; [
              bumper
            ];
          };

          release = pkgs.mkShell {
            packages = with pkgs; [
              flake-release
            ];
          };

          update = pkgs.mkShell {
            packages = with pkgs; [
              renovate
            ];
          };

          vulnerable = pkgs.mkShell {
            packages = with pkgs; [
              flake-checker # nix
              zizmor # actions
            ];
          };
        };

        # nix run [#...]
        apps = pkgs.mkApps {
          dev = "zig run src/main.zig";
        };

        # nix build [#...]
        packages = {
          default = pkgs.stdenv.mkDerivation (
            final: with pkgs.lib; {
              pname = "zig-template";
              version = "0.1.1";

              src = fileset.toSource {
                root = ./.;
                fileset = fileset.unions [
                  ./build.zig
                  ./build.zig.zon
                  ./LICENSE
                  ./src
                ];
              };

              nativeBuildInputs = with pkgs; [
                zig.hook
              ];

              checkPhase = ''
                zig fmt --check src
                zig build test
              '';

              meta = {
                mainProgram = "zig_template";
                description = "zig template";
                license = licenses.mit;
                platforms = platforms.all;
                homepage = "https://github.com/spotdemo4/zig-template";
                changelog = "https://github.com/spotdemo4/zig-template/releases/tag/v${final.version}";
                downloadPage = "https://github.com/spotdemo4/zig-template/releases/tag/v${final.version}";
              };
            }
          );
        };

        # nix build #images.[...]
        images = {
          default = pkgs.mkImage {
            src = self.packages.${system}.default;
          };
        };

        # nix fmt
        formatter = pkgs.treefmt.withConfig {
          configFile = ./treefmt.toml;
          runtimeInputs = with pkgs; [
            zig
            nixfmt
            oxfmt
          ];
        };

        # nix flake check
        checks = pkgs.mkChecks {
          zig = self.packages.${system}.default.overrideAttrs {
            dontBuild = true;
            installPhase = ''
              touch $out
            '';
          };

          nix = {
            root = ./.;
            filter = file: file.hasExt "nix";
            packages = with pkgs; [
              nixfmt
            ];
            script = ''
              nixfmt --check "$file"
            '';
          };

          actions = {
            root = ./.github/workflows;
            filter = file: file.hasExt "yaml";
            packages = with pkgs; [
              action-validator
              zizmor
            ];
            script = ''
              action-validator "$file"
              zizmor --offline "$file"
            '';
          };

          renovate = {
            root = ./.github;
            files = ./.github/renovate.json;
            packages = with pkgs; [
              renovate
            ];
            script = ''
              renovate-config-validator renovate.json
            '';
          };

          config = {
            root = ./.;
            filter = file: file.hasExt "json" || file.hasExt "yaml" || file.hasExt "toml" || file.hasExt "md";
            packages = with pkgs; [
              oxfmt
            ];
            script = ''
              oxfmt --check
            '';
          };
        };
      }
    );
}
