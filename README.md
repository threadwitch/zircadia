# Zircadia

An opinionated, signed [bootc](https://github.com/bootc-dev/bootc) desktop image:
a [niri](https://github.com/YaLTeR/niri) Wayland system with a gaming stack,
1Password, a curated set of CLI tools and fonts, and YubiKey support.

Zircadia is a thin customization layer built on top of
[zirconium](https://github.com/zirconium-dev) (Fedora + niri), published as an
OCI image to GHCR and delivered with bootc.

- Base: `ghcr.io/zirconium-dev/zirconium`
- Image: `ghcr.io/threadwitch/zircadia:latest`

## What it adds on top of the base

- **Gaming:** Steam, gamescope, MangoHud, vkBasalt, umu-launcher, faugus-launcher
  (Flatpak), ScopeBuddy, scx schedulers, InputPlumber, Waydroid, and related bits.
- **1Password:** desktop app + CLI, integrated for an ostree/bootc system
  (installed under `/usr/lib`, `/opt` symlink created at boot via tmpfiles.d,
  groups provisioned via sysusers.d). Helium is registered as an allowed browser.
- **CLI tools:** yazi, ripgrep, fd, fzf, zoxide, 7zip, ImageMagick, poppler,
  helium-browser.
- **Fonts:** Noto, Roboto, Atkinson Hyperlegible, several Nerd Fonts, and more.
- **Security:** YubiKey/U2F (pam-u2f, pam_yubico, yubikey-manager).
- **Branding:** os-release identifies the system as Zircadia.

Removed from the base: Firefox, valent, fedora-chromium-config, gamemode.

## Install

From an existing bootc system (Fedora Atomic, Bazzite, Bluefin, Aurora, …):

```bash
sudo bootc switch ghcr.io/threadwitch/zircadia:latest
```

Reboot to apply.

To build an installer ISO from the image, use the `iso` recipe (see below); the
ISO's kickstart rebases a fresh install onto `ghcr.io/threadwitch/zircadia:latest`.

## Update

```bash
zjust update
```

This upgrades the base image (`bootc upgrade`). Reboot to boot the upgraded
image.

To also update Flatpaks and Homebrew packages:

```bash
zjust update-all
```

## Verify the image signature

Images are signed with cosign. The public key ships at
[`cosign.pub`](./cosign.pub):

```bash
cosign verify --key cosign.pub ghcr.io/threadwitch/zircadia:latest
```

## Build locally

Requires `just` and `podman`.

```bash
just build          # build zircadia:latest
just iso            # build an installer ISO into ./output
```

Base images are pinned by digest in the [`Justfile`](./Justfile) and
[`.github/workflows/build.yml`](./.github/workflows/build.yml); digest bumps are
proposed by Renovate (see [`.github/renovate.json5`](./.github/renovate.json5)).

## Repository layout

- [`Containerfile`](./Containerfile) — image build entrypoint; runs the numbered
  scripts in `build_files/`.
- [`build_files/`](./build_files/) — single-purpose build steps (`01-source-fetch`
  through `99-final-hooks`).
- [`system_files/`](./system_files/) — files copied into the image
  (`/etc`, `/usr`), including the injected `zjust` recipes and Flatpak preinstalls.
- [`iso.toml`](./iso.toml), [`disk_config/`](./disk_config/) — installer/disk
  image configuration.
- [`.github/workflows/build.yml`](./.github/workflows/build.yml) — builds, signs,
  and pushes the image to GHCR on push and manual dispatch.
- [`DESIGN.md`](./DESIGN.md) — current-state assessment and successor direction.

## License

Apache-2.0. See [LICENSE](./LICENSE).
