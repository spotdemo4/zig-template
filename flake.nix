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

              vscode-json-languageserver # json
              yaml-language-server # yaml
              tombi # toml
              oxfmt # format

              # nix
              nixd
              nixfmt

              # util
              treefmt
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

        # nix build [#...]
        packages = {
          default = pkgs.stdenv.mkDerivation (
            final: with pkgs.lib; {
              pname = "zig-template";
              version = "0.7.0";

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
                    "arm64-apple-darwin"
                    "-unknown-"
                    "-w64-mingw32"
                  ]
                  [
                    "aarch64-macos-none"
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

              doCheck = true;
              checkPhase = ''
                runHook preCheck
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

              doInstallCheck = true;
              installCheckPhase = ''
                runHook preInstallCheck
                test "$("$out/bin/zig_template")" = "Hello, world!"
                runHook postInstallCheck
              '';

              meta = {
                mainProgram = "zig_template";
                description = "zig template";
                license = licenses.mit;
                platforms = platforms.all;
                homepage = "https://trev.zip/template/zig";
                downloadPage = "https://trev.zip/template/zig/releases";
                changelog = "https://trev.zip/template/zig/releases/tag/v${final.version}";
                sourceProvenance = [ sourceTypes.fromSource ];
                maintainers = [ maintainers.spotdemo4 ];
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

        # nix flake init -t git+https://trev.zip/template/zig
        templates = {
          default = {
            path = ./.;
            description = "zig template";
            welcomeText = ''
              # zig template

              `init.sh` requires a git repository with an `origin` remote:

              ```sh
              git init
              git remote add origin <url>
              bash init.sh "Title" "Description"
              ```
            '';
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
          inherit (self.packages.${system}) default;

          zig-lint = {
            root = ./.;
            filter = file: file.hasExt "zig";
            packages = with pkgs; [
              zig
            ];
            script = ''
              zig fmt --check "$file"
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
            files = ./.github/renovate.jsonc;
            packages = with pkgs; [
              renovate
            ];
            script = ''
              renovate-config-validator renovate.jsonc
            '';
          };

          renovate-fj = {
            root = ./.forgejo;
            files = ./.forgejo/renovate.jsonc;
            packages = with pkgs; [
              renovate
            ];
            script = ''
              renovate-config-validator renovate.jsonc
            '';
          };

          config = {
            root = ./.;
            filter =
              file:
              file.hasExt "json"
              || file.hasExt "jsonc"
              || file.hasExt "yaml"
              || file.hasExt "toml"
              || file.hasExt "md";
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
