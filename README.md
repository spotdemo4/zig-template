# zig template

[![check](https://img.shields.io/github/actions/workflow/status/spotdemo4/zig-template/check.yaml?branch=main&logo=github&logoColor=%23bac2de&label=check&labelColor=%23313244)](https://github.com/spotdemo4/zig-template/actions/workflows/check.yaml)
[![vulnerable](https://img.shields.io/github/actions/workflow/status/spotdemo4/zig-template/vulnerable.yaml?branch=main&logo=github&logoColor=%23bac2de&label=vulnerable&labelColor=%23313244)](https://github.com/spotdemo4/zig-template/actions/workflows/vulnerable.yaml)
[![zig](<https://img.shields.io/badge/dynamic/regex?url=https%3A%2F%2Fraw.githubusercontent.com%2Fspotdemo4%2Fzig-template%2Frefs%2Fheads%2Fmain%2Fbuild.zig.zon&search=.minimum_zig_version%20%3D%20%22(.*)%22&replace=%241&logo=zig&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%23F7A41D>)](https://ziglang.org/)
[![flakehub](https://img.shields.io/endpoint?url=https://flakehub.com/f/spotdemo4/zig-template/badge&labelColor=%23313244)](https://flakehub.com/flake/spotdemo4/zig-template)

template for [zig](https://ziglang.org/)

part of [spotdemo4/templates](https://github.com/spotdemo4/templates)

## requirements

- [nix](https://nixos.org/)

## getting started

```elm
nix develop
```

### run

```elm
nix run
```

### format

```elm
nix fmt
```

### check

```elm
nix flake check
```

### build

```elm
nix build
```

### release

```elm
bumper "README.md"
```

releases are created automatically for [significant](https://www.conventionalcommits.org/en/v1.0.0/#summary) changes

## use

### download

| OS      | Architecture | Download                                                                                                                                        |
| ------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Linux   | amd64        | [zig-template_0.0.2_linux_amd64](https://github.com/spotdemo4/zig-template/releases/download/v0.0.2/zig-template_0.0.2_linux_amd64)             |
| Linux   | arm64        | [zig-template_0.0.2_linux_arm64](https://github.com/spotdemo4/zig-template/releases/download/v0.0.2/zig-template_0.0.2_linux_arm64)             |
| Linux   | arm          | [zig-template_0.0.2_linux_arm](https://github.com/spotdemo4/zig-template/releases/download/v0.0.2/zig-template_0.0.2_linux_arm)                 |
| MacOS   | amd64        | [zig-template_0.0.2_darwin_amd64](https://github.com/spotdemo4/zig-template/releases/download/v0.0.2/zig-template_0.0.2_darwin_amd64)           |
| MacOS   | arm64        | [zig-template_0.0.2_darwin_arm64](https://github.com/spotdemo4/zig-template/releases/download/v0.0.2/zig-template_0.0.2_darwin_arm64)           |
| Windows | amd64        | [zig-template_0.0.2_windows_amd64.exe](https://github.com/spotdemo4/zig-template/releases/download/v0.0.2/zig-template_0.0.2_windows_amd64.exe) |

### docker

```elm
docker run ghcr.io/spotdemo4/zig-template:0.0.2
```

### nix

```elm
nix run github:spotdemo4/zig-template
```
