# DESIGN.md — Zircadia: Current State and Successor Direction

**Status:** Draft for review · 2026-06-11
**Scope:** This document records (1) an honest assessment of zircadia as it exists, (2) the options evaluated for its successor, and (3) the tentative direction with open workstreams. NixOS was explicitly excluded from this evaluation at the owner's direction.

---

## 1. What Zircadia Is Today

A thin customization layer (~8 shell scripts, ~250 lines) over a stack of third-party moving targets, built as a Podman/OCI layer and delivered via bootc.

### Dependency stack

```
Fedora 44
  └─ zirconium / zirconium-nvidia     ← third-party (zirconium-dev), built with mkosi,
  │                                      tracks niri-git, Terra, DankLinux theming
  └─ zircadia (this repo)             ← Containerfile layer: gaming stack, 1Password,
                                         CLI tools, fonts, YubiKey, branding
```

### Build-time inputs (all unpinned as of this writing)

| Input | Reference | Risk |
|---|---|---|
| `ghcr.io/zirconium-dev/zirconium{,-nvidia}` | `:latest` (implicit) | Silent base drift, daily |
| Terra repos (terra, -mesa, -nvidia, -extras) | live repo | Package drift every build |
| COPRs: lizardbyte/beta, faugus | live repo | Package drift, hobby-tier SLA |
| 1Password rpm repo | live repo, `stable` channel | Acceptable (vendor channel) |
| winetricks, gamecontrollerdb | raw `master` curls | Unpinned, unverified |
| `centos-bootc:stream10` (rechunker) | `:stream10` | Tooling drift |
| `bootc-image-builder`, `alpine` (CI) | `:latest` | Tooling drift |
| ublue-os/akmods images | pinned tag, **dead code** | Broken if re-enabled (see defects) |

The image rebuilds daily on cron (`build.yml`), so every unpinned input drifts silently every 24 hours. The instability experienced over the project's life is architectural, not incidental: the base image itself compiles niri from git snapshots.

### What the repo does right

- The customization layer is small, numbered, single-purpose; tmpfs build mounts keep `/var` clean; `bootc container lint` gates the build.
- cosign signing pipeline works end-to-end; `cosign.key` correctly gitignored.
- The 1Password ostree integration (`04-1p-install.sh`) is careful, well-commented work: sysusers.d groups with fixed GIDs, tmpfiles.d `/opt` symlink, helium added to allowed browsers.

### Known defects (remediation backlog)

1. **`iso.toml:4` rebases installs to the wrong image** — kickstart runs `bootc switch` to `ghcr.io/zirconium-dev/zirconium:latest`, so ISO installs silently lose all zircadia customization on first update. Fix: point at `ghcr.io/threadwitch/zircadia:latest`.
2. **Flatpak preinstall silently dead** — `system_files/usr/share/flatpak/preinstall.d/preinstall.d` lacks the required `.preinstall` extension and is ignored. Redundant anyway: faugus-launcher is also installed as an RPM (`03-gaming-install.sh:50`). Pick one.
3. **`Containerfile:8` references undeclared `${NVIDIA_FLAVOR}`** — expands to an invalid image ref. Only survives because the akmods stages are dead code (kernel install commented out). Fails the moment kernel work is re-enabled. The pinned `KERNEL_VERSION` ARG is stale baggage for the same disabled feature.
4. **dnf keepcache plumbing incoherent** — `01-source-fetch.sh` enables keepcache then its own EXIT trap disables it before any package-installing script runs; the `/var/cache/libdnf5` cache mount is mostly decorative.
5. **`build.yml` dead references** — `steps.load.outputs.digest` (no such step); manifest job greps with undefined `${IMAGE}` (works by accident, amd64-only); cron comment disagrees with cron expression.
6. **Template residue** — README is stock ublue template (documents files that don't exist here); `artifacthub-repo.yml` has placeholder ID; `iso-gnome.toml`/`iso-kde.toml` point at `ublue-os/image-template`; `JustfileU.bak` is dead; both dependabot and renovate run on github-actions; `quick-iterate` recipe builds a tag named `zirconium` and doesn't use it.
7. **Style drift** — `dnf` vs `dnf5`, `--enablerepo` vs `--enable-repo` (both valid in dnf5; pick one), inconsistent traps, leftover debug line at `03-gaming-install.sh:62`.

Cleanup cost: roughly one day. Nothing is load-bearing-but-opaque.

---

## 2. Goals (from owner objectives and `../linux_project` design docs)

- **Determinism as a core feature** — a build works the way it's declared, every time; all inputs pinned and content-addressed; drift only via explicit commit.
- **Control of the stack** — upstream changes arrive when chosen, not when published; ability to read and patch every layer above a well-defined base.
- **Shareability** — installable by non-expert friends: real install media, automatic updates, signed artifacts.
- **Variant support (long-term)** — niri+DMS (easy onboarding), niri-plain (owner's preference), KDE (aspirational; see §4).
- **Attestation/supply chain** — SBOMs, signing, provenance as build outputs, not afterthoughts.
- **Minimalism** — few tools known deeply; escape hatches explicit and documented as debt.

The full four-layer architecture (base image / package layer / configuration / GUI apps with explicit seams) is specified in `../linux_project/03_layered_os_design.md`. This document covers Layer 1 and its delivery seam; Layers 2–4 are out of scope here.

---

## 3. Options Evaluated

### A. Clean up and pin the existing Containerfile
Fix the defect backlog; pin `BASE_IMAGE` by digest with renovate bumps; pin curl'd files to tagged releases with checksums; pin tool images; reconsider the daily cron (build on push + base-bump instead).
**Cost:** ~days. **Gets:** all drift visible as reviewable PRs; "deterministic except package versions" (dnf against live Terra/COPR can't be pinned across builds without snapshot infrastructure that doesn't exist for those repos). **Doesn't get:** control of the base; zirconium remains an opaque binary dependency tracking niri-git.

### B. mkosi fork of zirconium
Zirconium is itself an mkosi project; this converts the binary dependency into a source dependency. Zircadia's layer ports in 1–2 days (package lists → conf.d drop-ins, `system_files/` → `mkosi.extra/`, scripts → postinst); a stable CI-built fork is 1–2 weeks.
**Gets:** source-level control, pin/patch everything in the Fedora stack. **Doesn't get:** package-level determinism (still dnf against live repos); adds permanent merge-from-upstream duty.

### C. BuildStream junction on zirconium-hawaii
Hawaii junctions freedesktop-sdk + gnome-build-meta and builds everything from pinned sources (git refs + per-crate/tarball sha256), exporting a bootc OCI image. Zircadia would junction hawaii and add/override elements.
**Gets:** total input pinning; drift structurally impossible without a commit; upstream artifact caches (GNOME, Bluefin) avoid rebuilding the world; hawaii already ships the OGC kernel, gamescope, steam, scx, inputplumber, umu, mangohud, niri. **Costs:** 2–4 weeks; hawaii is explicitly experimental ("will give you strange issues"); you become a distro maintainer — security updates arrive only when you bump refs.

### D. BuildStream from scratch (hawaii as inspiration, not dependency) ← **tentative direction**
Own project junctioning freedesktop-sdk (and gnome-build-meta only if needed), authoring the desktop/gaming/tooling elements directly, with hawaii's element set as reference material.
**Gets:** everything in C, plus authorship of every decision above the fdsdk junction — init/coreutils flavor, no-SUID posture, secure boot keys, session stack — consistent with the `linux_project` Layer 1 spec. **Costs:** 1–2 months of evenings to first boot (vs. C's 2–4 weeks); every authored element is a permanent version-bump obligation. Note: "from scratch" still means junctioning fdsdk — nobody hand-authors glibc elements; the decision is junction selection + element authorship, not zero dependencies.

**NixOS:** considered and excluded — rationale recorded 2026-06-11. The owner's objection is architectural, not aesthetic, and is grounded in jade.fyi's "The postmodern build system" (updated 2025):
- *The build model can't be upgraded in place.* The three mechanisms meant to modernize Nix's build model — ca-derivations (fixes rebuild-the-universe-on-glibc-bump), recursive Nix, and dynamic derivations — have all stalled for years and all three were **removed from Lix** due to implementation issues. The evaluator cannot resume evaluation while waiting on a build (IFD serializes), failing Tup's scalability rule without external orchestration. This is direct evidence that new lessons cannot be integrated into the existing plumbing.
- *Monolithic bump economics.* Input-addressing without working CA means every deep dependency bump rebuilds the world; nixpkgs absorbs this with a build cluster and a hundreds-of-TB cache. At personal scale the same property is unmitigated.
- *Real-world failure at exactly this seam:* Mercury spent 2022–2024 with strong engineers trying to bolt incremental builds onto Nix and abandoned it for Buck2 — supporting the judgment that Nix is a deployment model that the ecosystem retrofitted into roles it can't grow into.
- *Counterpoint, recorded for fairness:* nixpkgs' breadth is unmatched and NixOS would deliver Layers 1–3 of the `linux_project` architecture out of the box; the moat is the package universe, not the architecture. The owner accepts authoring elements in a far smaller universe (BuildStream/fdsdk) in exchange for plumbing that is simpler, applicative, and not load-bearing for a 100k-package monolith. The functional-configuration itch is deferred to Layers 2–3 (Nickel/Dhall/CUE candidates), where it doesn't require Nix's runtime.
- Note: BuildStream shares Nix's input-addressed rebuild property (no CA dedup); the mitigation here is universe size (hundreds of elements, upstream-cached fdsdk junction), not smarter addressing. This is a known, accepted cost.

### Why D over C (rationale)
Determinism is identical (a toolchain property, not an authorship property). D is chosen for control and legibility: elements you wrote are elements you can maintain, and hawaii's opinions (DMS theming, etc.) don't have to be inherited and then overridden. The cost difference (~2× to first boot) buys removal of a fragile dependency: hawaii is a one-maintainer experiment; junctioning it makes its instability yours with less visibility, not more.

---

## 4. Key Design Decisions for the Successor

### 4.1 Delivery: bootc OCI image (decided in principle)
The install story for a BuildStream OS is solved by **not** using BuildStream for delivery. Proven pattern (hawaii, Bluefin Dakota): `bst` builds and exports a filesystem tree → OCI image → `bootc container lint` → signed push. Everything zircadia already operates then applies unchanged: GHCR hosting, cosign, installer ISOs, `bootc switch` migration for existing bootc users, automatic updates.

Evidence this is friend-ready: Dakota Alpha 1 (2026-04) shipped a live ISO via tuna-installer (generic bootc installer); Alpha 2 (2026-06) has working LUKS-on-install and delta-friendly layering via the Chunkah rechunker; beta ~July, GA targeted fall 2026.

**Rejected alternative:** GNOME OS-native delivery (systemd-sysupdate + UKI/DDI). Architecturally purer (measured boot, A/B updates) and closer to the long-term Layer 1 ideal, but the installer is early-stage and the layout is still moving (Dakota: "cannot guarantee this installation will be the final layout"). Revisit post-GA of the GNOME OS sysupdate stack. Design the OCI assembly so the tree could later be emitted as a DDI without re-architecting elements.

### 4.2 Variant matrix (decided in principle)
Variants are BuildStream stack elements sharing the artifact cache; a second variant costs one stack file plus assembly time.

- **niri + DMS** — friends/onboarding variant.
- **niri plain** — owner's variant.
- **KDE — explicitly out of scope.** No KDE equivalent of gnome-build-meta exists; a KDE variant means authoring and maintaining Qt 6 + ~80 Frameworks + Plasma as elements — a multi-month project and permanent treadmill. KDE-wanting friends should be pointed at KDE Linux (KDE's own image-based OS). Reassess only if a community KDE BuildStream meta-project emerges.

### 4.3 Junction policy (open, must be decided early)
- fdsdk branch selection (e.g., 25.08 stable series as hawaii uses) and bump cadence — junction bumps are the **security update channel**; define a target latency (e.g., within a week of fdsdk point releases).
- Whether gnome-build-meta is needed at all for a niri-only image (likely minimal or none — audit which hawaii elements actually pull from it).
- Pin junctions by exact commit; bumps land as ordinary reviewed commits.

### 4.4 Element update automation (open, required before GA-to-friends)
Dakota's team — professional ops people — admits version bumping is still manual. As one person, automation is not optional:
- CI job running `bst source track` per element on a schedule, opening PRs (the BuildStream analogue of renovate; nothing off-the-shelf exists — budget for building this).
- Proprietary/prebuilt elements (1Password, helium) need explicit version variables + sha refs bumped via scripted check against vendor release feeds.
- Without this, the project recreates zircadia's neglect-drift problem with higher stakes (you are the only security responder).

### 4.5 Inventory by destination layer (revised)
The original sort here was by element-porting cost, which wrongly assumed everything zircadia ships belongs in the image. Per the `linux_project` architecture, **Layer 2 (homebrew-like package layer with Nix-correct hermetic builds and pinning) is the default destination for user-facing software**; the image (Layer 1) ships only what must be present at boot/session/driver/update level.

- **Layer 1 — in-image elements:** kernel (linux-ogc recipe exists in hawaii), mesa, niri + session glue, gamescope/steam runtime integration (32-bit, udev, drivers), scx-scheds/tools + scx_loader config, inputplumber, powerstation, steamos-manager, initramfs, OCI assembly. Mostly covered by fdsdk + hawaii-as-reference.
- **Layer 2 — package layer (see §5.5):** yazi, fd, ripgrep, fzf, zoxide, ImageMagick, umu-launcher, mangohud, scopebuddy, winetricks, gamecontrollerdb, helium(?). Mostly Rust/Go/static-friendly — which matters: static linking collapses the dependency-resolution problem that makes package managers hard.
- **Boundary test cases (decide deliberately):** 1Password (setgid groups, sysusers.d, browser-integration paths — system-flavored, probably Layer 1), helium (user-space browser, plausible Layer 2 if its sandbox works unprivileged), fonts (Layer 1 for session defaults vs. Layer 3 for user choice).
- **Layer 1 hard items / decide-or-drop:** waydroid (LXC + kernel module), YubiKey PAM stack (PAM config against an fdsdk base), printing (CUPS), intel-opencl. These cannot live in a user-space prefix; they are image work or they are cut.

---

## 5. Open Workstreams

### 5.1 Layer decomposition
Map the successor onto the `linux_project` four-layer model with an explicit default rule: **if it is not required for boot, drivers, session, or updates, it is Layer 2 (or 3/4) unless argued otherwise.** Initial sort is in §4.5. Remaining calls: faugus (Layer 4 — flatpak, done properly this time), proton env defaults and scx_loader config (Layer 3 vs. baked — decide the seam). The image shrinks toward "boots, drives the GPU, runs the session, updates itself" — which also converges the image variants (friend-customization moves to Layer 2/3 manifests instead of image forks).

### 5.5 Layer 2 package layer (flagship workstream)
Layer 2 is **the big part of the project**: a homebrew-like user-space package layer with Nix-correct properties, designed from the start to scale to a community of maintainers. Design properties beyond the original spec:

- **Scale is a requirement, not an aspiration.** Multiple maintainers, decentralized contribution (tap-like repos rather than a monorepo), low barrier to writing a package definition. This is primarily a social-architecture problem; Homebrew's success is taps + trivially writable formulae + CI bottling, not its build model.
- **BuildStream is rejected for Layer 2** (superseding the earlier unified-toolchain proposal, which remains valid only as long as Layer 2 is one person's ~50 packages): monorepo element trees don't decompose into independent community repos; contributor UX (element YAML + junction mechanics + CAS server operations) is a prohibitive barrier vs. a formula-like format; BuildStream has no install side; and its centralized artifact-cache topology fights decentralized maintainership. BuildStream remains Layer 1 only.
- **Minimal build sandboxes.** As little as possible running inside each build: no full distro image per build, declared inputs only, hermetic by construction.
- **Attestation as a first-class output.** Build provenance (sigstore/SLSA-style) plus, longer-term, trust through independent reproduction (rebuilderd-style verification, multi-party signing à la stagex) rather than trust through authority.
- **Runtime sandboxing by default.** Packages run under bubblewrap (or equivalent) with declared access — the Flatpak idea applied to CLI/user packages, where no one currently applies it. Plan 9-style per-process namespace composition (each package sees only its declared deps union-mounted into place) is an open research direction for both the install layout and the sandbox model; see distri (Stapelberg) for evidence the mount-based approach performs fine.

**Prior art to study before building** (ordered by proximity to the vision): Chainguard's melange/apko + Wolfi (declarative YAML package builds in minimal bwrap sandboxes, apk output, sigstore-signed, explicitly built to scale maintainers — the closest existing system; study why their stack looks the way it does, and what it lacks: runtime sandboxing, user-space install story); stagex (full-source-bootstrapped, deterministic, multi-party-signed toolchain — the trust-root model); distri (package-per-image, mount-composed — the Plan 9-adjacent install model); rebuilderd (independent reproduction verification); Spack, pixi/rattler-build (lockfile/binary-cache mechanics); Homebrew (UX + community model reference; note it has shipped sigstore build provenance on bottles since 2024).

**Dependency model (tentative): per-process mount composition with per-app lockfile closures.** Multiple coexisting versions of dynamic libraries — the problem nix-store solves with per-package store paths and RPATH rewriting — is handled instead at the namespace level: the resolver computes one coherent closure per application, and the sandbox mounts exactly those dependency trees at conventional FHS paths. Key distinction: Nix resolves per dependency-*edge* (each binary's RPATH pins each dep's exact build); mount composition resolves per-*process-namespace* (one version per soname per app closure). The residual gap — same soname, different builds, inside one process — is rare, usually a bug, and partially painful even in Nix; accepted. Major dividend: **no build-time path rewriting at all** (no patchelf, no RPATH surgery, binaries stay FHS-compatible) — which removes the single largest source of imperative per-package fixup scripting in Nix-style systems and directly serves the no-bash goal below.

**Package format (tentative): no apk, no inherited format.** Under mount composition the package format nearly dissolves: a package is a content-addressed immutable filesystem tree plus a manifest. Modern mechanism: EROFS/composefs images with fs-verity — kernel-enforced integrity at mount time, i.e. attestation that is *verified on every execution*, not just at download. This is the direction the ostree/bootc/Flatpak ecosystem is already converging on, and it means Layer 2 need not adopt apk-tools or any Alpine-derived format. (Owner constraint, recorded: minimize dependence on apk-tools/Alpine-maintainer-derived components; melange/Wolfi remain study material and acceptable short-term tooling, but are targeted for obsolescence.)

**Definition language (requirement): functional, typed, no packager-authored shell.** melange's shape — imperative bash steps inside a logic-free YAML envelope — is rejected; it is the worst of both worlds. Architecture: a **two-language split**. (a) A functional definition language with real logic and types, which *evaluates* to (b) a serialized, static build plan — argv-level actions (fetch/unpack/patch/exec with declared env, cwd, inputs) executed by a minimal non-shell executor in the sandbox. Proven flavors of exactly this architecture: Starlark → action graph (Bazel/Buck2 — deterministic, no shell, industrial scale), Guile G-expressions (Guix — staged functional build code, the closest realized "no bash in builds"), Nickel/CUE (typed config with functions, contracts). Honest limit, recorded: "no bash" means no *packager-authored* shell; upstream build systems (autotools `./configure` is itself a shell script) may still require a `sh` in the sandbox as a declared tool dependency. The achievable bar is that all packaging logic is functional and typed, and the sandbox shell, where unavoidable, runs only upstream's own scripts.

**Relationship to Layer 4 / Flatpak: delegation, not architecture.** Layer 2's mechanism (bwrap + content-addressed trees + declared access) makes Flatpak architecturally non-unique — in the limit, a Layer 2 GUI app with portal support is indistinguishable from a flatpak, and both converge on composefs storage. What Flatpak retains is (a) **portals** — runtime user-mediated capability grants, required for GUI sandboxing to be real rather than theater; these are a D-Bus protocol, not Flatpak-exclusive (bubblejail is prior art for third-party bwrap sandboxes using them), and are adopted as the capability layer for any graphical Layer 2 package — Seam 3's structured portal-permission declarations apply identically to both; and (b) **Flathub's maintenance labor** — the delegated long tail of upstream-maintained apps, which no solo project can absorb. The Layer 2/4 boundary is therefore economic: Layer 2 = builds the owner chooses to own; Layer 4 = software deliberately delegated. Apps may migrate inward over time (helium is a plausible early migrant). Resulting property (scoped): on a non-developer system, the attestation gap reduces to the flatpak list — enumerable on demand. On developer machines, language/toolchain package managers (cargo, npm, pip, go, rustup, …) are a second, irreducible gap class; subsuming them is explicitly a non-goal (the Nix ecosystem's per-language `*2nix` sprawl is the cautionary tale). The honest property is that the gap is *enumerable by class* — flatpaks plus toolchain trees — not that it closes. Marginal mitigations (ecosystem-native provenance like npm/PyPI attestations, lockfile auditing) are upstream's lane, not Layer 2's.

**Shell/POSIX posture.** Interactive shell is a free Layer 3 choice (oils/ysh, nushell candidates). The base image can approach sh-free: systemd units are argv-based by design, and a systemd/mkosi-style initramfs removes dracut's bash. The irreducible residue — upstream build scripts in sandboxes, runtime software that shells out — is handled by demotion, not elimination: `sh` is a declared dependency of specific packages, never ambient. Auditable presence, not absence.

**Interim: Homebrew, explicitly marked as documented debt** per the project's own escape-hatch principle. It violates pinning and hermeticity (acceptable short-term), is the proven pattern on image-based OSes (Bluefin ships it), and its bottle provenance attestations mean the interim is not attestation-free. Exit criterion: first usable Layer 2 milestone covering the owner's own CLI set.

### 5.2 CI tooling
- **Builder:** `bst2` runs in the fdsdk builder container (hawaii pattern: podman + `--device /dev/fuse`). GitHub Actions is viable (Dakota uses it); fdsdk/GNOME themselves use GitLab CI. Decide: stay on GH Actions (existing familiarity, free for public repos) vs. GitLab (native BuildStream culture, better caching primitives).
- **Pipeline shape:** track-PRs → build → cache push → OCI assembly → lint → sign → push → ISO build. The back half is zircadia's existing pipeline.
- **Runner economics:** cold builds of a desktop stack will not fit free GH runner time without a warm artifact cache. The cache (5.3) is therefore on the critical path for CI, not an optimization.

### 5.3 Artifact storage (the real infrastructure cost)
- BuildStream caches are CAS servers (buildbox-casd / bst-artifact-server protocol). Upstream caches (gbm.gnome.org, cache.projectbluefin.io) can be configured pull-only for junctioned elements — that covers fdsdk; **own elements need an own push cache.**
- Options to evaluate: self-hosted CAS on a VPS with a few hundred GB (likely cheapest), object-storage-backed deployment, or rebuilding own elements every CI run (viable early while the element count is small — measure before buying infrastructure).
- OCI artifacts and ISOs stay on GHCR + existing S3/rclone pipeline (already built in `build-disk.yml`).
- Secure boot: hawaii's Justfile has the key-generation recipe (PK/KEK/DB/module keys). Decide: own keys + friend enrollment instructions, or ship unsigned and require SB-off initially (Dakota is UEFI-only with its own story — check their approach at beta).

### 5.4 Interim zircadia maintenance
Zircadia remains the daily driver until the successor boots. Minimum viable maintenance, not investment:
1. Fix `iso.toml` rebase target (defect #1) — anything installed from current media is broken by design.
2. Pin `BASE_IMAGE` by digest; replace the daily cron with push + manual dispatch. This stops the nightly drift for ~an hour of work and makes the remaining zircadia lifetime calmer.
3. Optionally clear the rest of the defect backlog (§1) if zircadia's lifetime looks like months rather than weeks.

---

## 6. Decision Log

| Date | Decision | Status |
|---|---|---|
| 2026-06-11 | NixOS excluded from this evaluation | Directed |
| 2026-06-11 | NixOS exclusion rationale recorded (build-model tech debt; see §3) | Recorded |
| 2026-06-11 | Successor built with BuildStream, fdsdk junction, own elements (Option D) | Tentative |
| 2026-06-11 | Delivery via bootc OCI + existing ISO/signing pipeline; sysupdate/DDI deferred | Tentative |
| 2026-06-11 | KDE variant out of scope; DMS/plain variants via stacks | Tentative |
| 2026-06-11 | Layer 1/2 boundary rule: image ships boot/driver/session/update only; user software defaults to Layer 2 | Tentative |
| 2026-06-11 | ~~Layer 2 build side reuses BuildStream toolchain~~ | Superseded same day |
| 2026-06-11 | Layer 2 is the flagship project: community-scalable, attested, runtime-sandboxed by default; BuildStream is Layer 1 only | Tentative |
| 2026-06-11 | Interim Layer 2 = Homebrew, recorded as documented debt with exit criterion | Decided |
| 2026-06-11 | Layer 2 dependency model: per-app lockfile closures + mount composition; no RPATH rewriting | Tentative |
| 2026-06-11 | Layer 2 format: CAS-addressed composefs/EROFS + fs-verity; no apk / Alpine-derived components (owner constraint) | Tentative |
| 2026-06-11 | Layer 2 definitions: functional typed language → serialized argv build plan; no packager-authored shell | Tentative |
| 2026-06-11 | Layer 4 boundary redefined as delegation (own the build vs. delegate to Flathub); portals adopted for Layer 2 GUI sandboxes; sh demoted to declared dependency, never ambient | Tentative |
| 2026-06-11 | Junction policy, update automation, CI host, cache hosting, Seam 1 ABI contract | Open |

---

*References: zirconium-dev/zirconium-hawaii (BuildStream→bootc pattern, element inventory), projectbluefin/dakota + Alpha 1/2 announcements (install story, rechunking, timeline), GNOME OS sysupdate migration (Codethink), `../linux_project/` design documents (layered architecture, objectives).*
