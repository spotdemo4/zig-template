# contributing

## requirements

- [nix](https://nixos.org/)

## getting started

```sh
nix develop
```

### run

```sh
zig build run
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
