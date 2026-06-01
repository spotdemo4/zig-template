# zig template

[![check](https://trev.zip/template/zig/actions/workflows/check.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=check&labelColor=%23313244)](https://trev.zip/template/zig/actions?workflow=check.yaml)
[![vulnerable](https://trev.zip/template/zig/actions/workflows/vulnerable.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=vulnerable&labelColor=%23313244)](https://trev.zip/template/zig/actions?workflow=vulnerable.yaml)
[![zig](<https://img.shields.io/badge/dynamic/regex?url=https://trev.zip/template/zig/raw/branch/main/build.zig.zon&search=.minimum_zig_version%20%3D%20%22(.*)%22&replace=%241&logo=zig&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%23F7A41D>)](https://ziglang.org/)

template for [zig](https://ziglang.org/)

part of [spotdemo4/templates](https://github.com/spotdemo4/templates)

## requirements

- [nix](https://nixos.org/)

## getting started

```sh
nix develop
```

### run

```sh
nix run .#dev
```

### format

```sh
nix fmt
```

### check

```sh
nix flake check
```

### build

```sh
nix build
```

### release

```sh
bumper
```

releases are created automatically for [significant](https://www.conventionalcommits.org/en/v1.0.0/#summary) changes

## use

### docker

```sh
docker run trev.zip/template/zig:latest
```

### nix

```sh
nix run git+https://trev.zip/template/zig.git
```

### download

https://trev.zip/template/zig/releases
