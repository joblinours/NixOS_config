# Toolchains de développement. VS Code est géré par home-manager.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # IA
    claude-code

    # C / C++
    gcc
    clang
    clang-tools # clangd, clang-format, clang-tidy
    gnumake
    cmake
    meson
    ninja
    pkg-config
    gdb
    valgrind

    # Rust : `rustup default stable` au premier lancement
    rustup

    # Python : uv gère venvs, dépendances (uv add) et versions de Python
    python3
    uv

    # Web
    nodejs
    pnpm

    # Go, Java
    go
    jdk21

    # Git / SSH
    lazygit
    sshm
    lazyssh # TUI de gestion SSH (lit ~/.ssh/config) ; alias lssh
  ];
}
