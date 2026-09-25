# zig template

[![check](https://trev.zip/template/zig/actions/workflows/check.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=check&labelColor=%23313244)](https://trev.zip/template/zig/actions?workflow=check.yaml)
[![vulnerable](https://trev.zip/template/zig/actions/workflows/vulnerable.yaml/badge.svg?branch=main&logo=forgejo&logoColor=%23bac2de&label=vulnerable&labelColor=%23313244)](https://trev.zip/template/zig/actions?workflow=vulnerable.yaml)
[![nixpkgs](https://nix-shield.trev.zip/?url=https://trev.zip/template/zig/raw/branch/main/flake.lock&input=nixpkgs&logoColor=%23bac2de&labelColor=%23313244&color=%235277C3)](https://nixos.org/)
[![zig](<https://img.shields.io/badge/dynamic/regex?url=https://trev.zip/template/zig/raw/branch/main/build.zig.zon&search=.minimum_zig_version%20%3D%20%22(.*)%22&replace=%241&logo=zig&logoColor=%23bac2de&label=version&labelColor=%23313244&color=%23F7A41D>)](https://ziglang.org/)

template for [zig](https://ziglang.org/)

to initialize a new project, run:

```sh
./init.sh "Title" "Description"
```

part of [spotdemo4/templates](https://github.com/spotdemo4/templates)

## using

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

## contributing

see [CONTRIBUTING.md](CONTRIBUTING.md) for requirements and getting started
