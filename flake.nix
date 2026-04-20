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
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    trev = {
      url = "github:spotdemo4/nur";
      inputs.systems.follows = "systems";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      trev,
      ...
    }:
    trev.libs.mkFlake (
      system: pkgs: {
        devShells = {
          default = pkgs.mkShell {
            shellHook = pkgs.shellhook.ref;
            packages = with pkgs; [
              zig
              zls
              lldb

              # format
              nixfmt
              prettier

              # util
              bumper
              flake-release
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
              flake-checker # flake
              zizmor # actions
            ];
          };
        };

        checks = pkgs.mkChecks {
          zig = {
            src = self.packages.${system}.default;
            script = ''
              zig build test
            '';
          };

          actions = {
            root = ./.;
            files = ./.github/workflows;
            packages = with pkgs; [
              action-validator
              zizmor
            ];
            forEach = ''
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

          nix = {
            root = ./.;
            filter = file: file.hasExt "nix";
            packages = with pkgs; [
              nixfmt
            ];
            forEach = ''
              nixfmt --check "$file"
            '';
          };

          prettier = {
            root = ./.;
            filter = file: file.hasExt "yaml" || file.hasExt "json" || file.hasExt "md";
            packages = with pkgs; [
              prettier
            ];
            forEach = ''
              prettier --check "$file"
            '';
          };
        };

        formatter = pkgs.treefmt.withConfig {
          configFile = ./treefmt.toml;
          runtimeInputs = with pkgs; [
            zig
            nixfmt
            prettier
          ];
        };

        packages.default = pkgs.stdenv.mkDerivation (
          final: with pkgs.lib; {
            pname = "zig-template";
            version = "0.0.2";

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

        images.default = pkgs.mkImage {
          src = self.packages.${system}.default;
        };

        schemas = trev.schemas;
      }
    );
}
