# contributing

## requirements

- [nix](https://nixos.org/)

## getting started

```sh
nix develop
```

with [direnv](https://direnv.net/):

```sh
ln -s .envrc.project .envrc
direnv allow
```

### run

```sh
nix run
```

with [zig](https://ziglang.org/):

```sh
zig build run
```

### format

```sh
nix fmt
```

with [zig](https://ziglang.org/):

```sh
zig fmt build.zig src
```

### check

```sh
nix flake check
```

with [zig](https://ziglang.org/):

```sh
zig build test
```

### build

```sh
nix build
```

with [zig](https://ziglang.org/):

```sh
zig build
```

### release

with [bumper](https://trev.zip/llc/bumper):

```sh
bumper
```

releases are created automatically for [significant](https://www.conventionalcommits.org/en/v1.0.0/#summary) changes
