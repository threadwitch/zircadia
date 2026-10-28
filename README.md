# Zircadia

An opinionated, signed [bootc](https://github.com/bootc-dev/bootc) desktop image:
a [niri](https://github.com/YaLTeR/niri) Wayland system with a gaming stack,
a curated set of CLI tools and fonts, and YubiKey support.

Zircadia is a thin customization layer built on top of
[zirconium](https://github.com/zirconium-dev) (Fedora + niri), published as an
OCI image to GHCR and delivered with bootc.

- Base: `ghcr.io/zirconium-dev/zirconium`
- Image: `ghcr.io/threadwitch/zircadia:latest`

## What it adds on top of the base

- **Gaming:** Steam, gamescope, MangoHud, vkBasalt, umu-launcher, faugus-launcher
  (Flatpak), ScopeBuddy, scx schedulers, InputPlumber, Waydroid, and related bits.
- **CLI tools:** yazi, ripgrep, fd, fzf, zoxide, 7zip, ImageMagick, poppler,
  helium-browser.
- **Fonts:** Noto, Roboto, Atkinson Hyperlegible, several Nerd Fonts, and more.
- **Security:** YubiKey/U2F (pam-u2f, pam_yubico, yubikey-manager).
- **Branding:** os-release identifies the system as Zircadia.

The 1Password recipe is retained for reference but disabled; its packages and
dedicated integrations are no longer added to the image.

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

Run the lightweight maintenance regression checks without building an image:

```bash
python3 -m unittest discover -s tests -v
for script in build_files/*.sh; do bash -n "${script}"; done
```

The disk-image workflow targets amd64, matching the published container image.
It uses the same upstream builder as the local ISO recipes, with btrfs for the
installer ISO and ext4 for qcow2. Its PR runs validate installer generation from
the existing published `:latest` image, not the container built by that PR.
Testing installers for a new image requires publishing it first, then rerunning
the disk-image workflow.

Base images are pinned by digest in the [`Justfile`](./Justfile) and
[`.github/workflows/build.yml`](./.github/workflows/build.yml); digest bumps are
proposed by Renovate (see [`.github/renovate.json5`](./.github/renovate.json5)).

## Fedora 45 transition and CA remediation

The pinned base is Fedora 45. Its inherited CA package must be at least
`2026.2.92_v9.0.319-2.fc45`; older/missing bundles fail without downloading a
Fedora 44 package. TLS and code-signing fingerprint checks remain mandatory.
Unsupported Fedora releases fail closed. The disabled, unused Fedora 44 akmods
stage was removed; this image continues to inherit its kernel from Zirconium.

Terra's Fedora 45 vendor repo layout (`/usr/share/dnf5/repos.d`) and the older
`/etc/yum.repos.d` layout are both handled at finalization, with disabled copies
available to the installer dependency solver. Fedora's native `fdk-aac-free`
package is used with matching x86_64/i686 versions, without a fixed versionlock
or exclusion. It retains ordinary AAC support, but not FDK HE/HEv2 profiles.
The full Terra codec can be reconsidered when a compatible F45 package becomes
available; this is not an automatic switch or a claim of media feature parity.
A container build does not validate boot, desktop, hardware or installer behavior.

For deliberate Fedora 44 builds, the first image-build step retains the isolated
fallback which installs only the signed Fedora 44
`ca-certificates-2026.2.92_v9.0.319-2.fc44` package from
[Koji build 3125414](https://koji.fedoraproject.org/koji/buildinfo?buildID=3125414).
It pins the RPM's SHA-256, checks its signature against existing RPM keys, and
requires DNF's local-package signature verification with every repository
disabled. It does not enable updates-testing or import additional keys.
[The Fedora update](https://bodhi.fedoraproject.org/updates/FEDORA-2026-0609e13c0d)
was published stable on October 23, 2026. This follow-up includes the additional
`emSign Root CS CA - G3` code-signing root removal beyond the `-1.fc44` fix.

This removes the affected emSign roots and the AAA Certificate Services trust
path from Fedora's default bundle. Connections still relying on those roots may
fail. Custom trust inputs are preserved, and applications with separate or
bundled trust stores need their own updates. This is not a claim that every
application is remediated.

The build fails if the package cannot be downloaded or verified, dependencies
cannot be satisfied without another package, or the installed version remains below the fix. Newer upstream bundles are kept,
using RPM's epoch/version/release comparison instead of a downgrade. The build
also checks the three explicitly patched roots by SHA-256 fingerprint in both
TLS server-authentication and code-signing anchors. It fails if any remains,
including one added by custom configuration; those inputs are left intact for
explicit review. A successfully extracted empty code-signing anchor set is valid,
but an empty TLS anchor set or a failed extraction/fingerprint check fails closed.
Remove the temporary package override once it is no longer needed upstream.
No image is deployed by a PR build.

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
