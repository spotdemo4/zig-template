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
              version = "0.3.0";

              src = fileset.toSource {
                root = ./.;
                fileset = fileset.unions [
                  ./build.zig
                  ./build.zig.zon
                  ./LICENSE
                  ./src
                ];
              };

              zigTarget =
                replaceStrings
                  [
                    "-unknown-"
                    "-w64-mingw32"
                  ]
                  [
                    "-"
                    "-windows-gnu"
                  ]
                  (
                    replaceStrings
                      [
                        "armv7l-"
                      ]
                      [
                        "arm-"
                      ]
                      pkgs.stdenv.hostPlatform.config
                  );
              zigTargetFlags = optionals (pkgs.stdenv.hostPlatform.config != pkgs.stdenv.buildPlatform.config) [
                "-Dtarget=${final.zigTarget}"
              ];
              zigBuildFlags = final.zigTargetFlags ++ [
                "-Doptimize=ReleaseSafe"
              ];
              canRunTarget = pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform;

              nativeBuildInputs = with pkgs; [
                buildPackages.zig
              ];

              dontConfigure = true;
              doCheck = true;

              zigCacheSetup = ''
                export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
                export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
              '';
              preBuild = final.zigCacheSetup;
              preCheck = final.zigCacheSetup;

              buildPhase = ''
                runHook preBuild
                zig build --prefix zig-out ${escapeShellArgs final.zigBuildFlags}
                runHook postBuild
              '';

              checkPhase = ''
                runHook preCheck
                zig fmt --check src
                ${optionalString final.canRunTarget ''
                  zig build test ${escapeShellArgs final.zigBuildFlags}
                ''}
                runHook postCheck
              '';

              installPhase = ''
                runHook preInstall
                cp -R zig-out "$out"
                runHook postInstall
              '';

              meta = {
                mainProgram = "zig_template";
                description = "zig template";
                license = licenses.mit;
                platforms = platforms.all;
                homepage = "https://trev.zip/template/zig";
                changelog = "https://trev.zip/template/zig/releases";
                downloadPage = "https://trev.zip/template/zig/releases/tag/v${final.version}";
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

          actions-gh = {
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

          actions-fj = {
            root = ./.forgejo/workflows;
            filter = file: file.hasExt "yaml";
            packages = with pkgs; [
              forgejo-runner
              zizmor
            ];
            script = ''
              forgejo-runner validate --workflow --path "$file"
              zizmor --offline "$file"
            '';
          };

          renovate-gh = {
            root = ./.github;
            files = ./.github/renovate.json;
            packages = with pkgs; [
              renovate
            ];
            script = ''
              renovate-config-validator renovate.json
            '';
          };

          renovate-fj = {
            root = ./.forgejo;
            files = ./.forgejo/renovate.json;
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
