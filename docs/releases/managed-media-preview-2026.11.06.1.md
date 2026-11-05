# Portfolio preview: managed-media-preview-2026.11.06.1

Release date: November 6, 2026 (Asia/Bangkok).

## What is downloadable

`MLX-Serve-managed-media-macos-arm64.zip` contains the installed, optimized personal Mac app, including its native server, bundled libraries, license files, and fonts. It is an arm64 app; it is not an Intel, Windows, or Linux distribution. The binary's displayed version remains the upstream-based `26.11.1`; the distinct fork release tag identifies this preview.

`BUILD-INFO.json` identifies the binary source commit, dependency versions, signature type, declared OS floor, and validation provenance. `SHA256SUMS.txt` lets a recipient verify the asset bytes. GitHub's automatic source archives describe the release-tagged repository; submodule-based builds still need their pinned dependencies.

**The app archive is not a complete runtime installer.** It excludes models, the MLX-Gen virtual environment, stable-diffusion.cpp, FFmpeg, Homebrew, and Python. Those were already installed separately on the tested Mac. A new-machine installation of this exact arrangement has not been validated.

## Required external layout

| Component | Default path or prerequisite |
|---|---|
| MLX-Gen | `~/.mlx-serve/runtimes/mlx-gen/.venv/bin/mlxgen` |
| stable-diffusion.cpp | `~/.mlx-serve/runtimes/stable-diffusion/bin/sd-cli` |
| FFmpeg | `/opt/homebrew/bin/ffmpeg` or `/usr/local/bin/ffmpeg` |
| Python | Tested environment uses Homebrew Python 3.14.8 |
| WebP libraries | The tested sd-cli links to Homebrew WebP libraries |
| Models | App model library or a configured existing model folder; never bundled in the release |

Explicit executable overrides are `MLX_SERVE_MLXGEN_PATH`, `MLX_SERVE_SDCLI_PATH`, and `MLX_SERVE_FFMPEG_PATH`. A Finder-launched app does not automatically inherit variables from an interactive shell. On the tested Mac, default paths are used.

## Runtime provenance

- MLX-Gen source: [`99fb94dd3eaa9dd1931cd3cd8eae1ae3e20f2ef3`](https://github.com/lpalbou/mlx-gen/commit/99fb94dd3eaa9dd1931cd3cd8eae1ae3e20f2ef3), installed as a non-editable package, reporting 0.38.0.
- stable-diffusion.cpp: [`58bb3c1b1cd4749e94e39f537e9adfce295dcaee`](https://github.com/leejet/stable-diffusion.cpp/commit/58bb3c1b1cd4749e94e39f537e9adfce295dcaee).
- Its ggml submodule: `135ce1e0e3f2b0693d3de93d4f6b5fa0a1947820` in [leejet/ggml](https://github.com/leejet/ggml), with this fork's [mixed-precision patch](../../patches/stable-diffusion-ggml-mixed-precision.patch) applied.
- The tested video engine was built with Metal enabled and `GGML_METAL_EMBED_LIBRARY=ON`. Its shaders are embedded; the development source tree is not a runtime requirement.
- The Python environment's MLX version is 0.31.0; the app's separately bundled native server reports MLX 0.32.3. They are separate installations, not a single shared library version.

These are reproduction inputs and evidence, not a tested clean-machine installation script. Do not substitute an arbitrary stable-diffusion.cpp build and assume the mixed-precision issue is resolved. Upstream build information: [MLX-Gen](https://github.com/lpalbou/mlx-gen), [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp), and this fork's [integration record](../external-media-integration.md).

## Selected model workflows

For No. 5, open Image Generation → Upscale. Search/select `AbstractFramework/seedvr2-7b-8bit`, download it in the app, choose an input and PNG destination, then upscale. The recorded 4× test produced a valid 1024×1024 output from 256×256 input.

For No. 6, search the GGUF model list for `frtertaer/LTX-2.5-uncensored-v1.1-FP8` and select **Q4_K_M**, then open Video Generation → GGUF. Select the downloaded model and download missing components. The compatible route uses the standard LTX 2.5 convolutional video VAE plus this pack's audio VAE and Q4 text encoder. Choose an MP4 destination and generate. The app manages inference and conversion; no second media front end is required.

The pack's “uncensored” name is not a measured refusal guarantee. Models remain subject to their own licenses. These checkpoint choices are not redistributed by this release.

## Signing and updates

This app is ad-hoc signed and not Apple-notarized. Strict deep signature verification passed for the packaged installed app, but that does not make it an Apple-approved distribution. A recipient's macOS security policy can prevent it from opening. A Developer ID signed and notarized release is the appropriate next step for routine public distribution; this guide does not instruct recipients to bypass macOS security protections.

The declared OS minimum is macOS 26.2. The release audit Mac reports macOS 27.0.1, Apple M5 Pro, and 64 GiB unified memory (68,719,476,736 bytes / 1,073,741,824 = 64 GiB). Broad OS/hardware compatibility is untested.

The built-in update checker still points to `ddalcu/mlx-serve`; this preview does not configure a fork-specific update feed. An upstream update may replace the custom app. Upstream Homebrew/DMG links likewise install upstream, not this fork.

## Validation status

The November 5 integration suite recorded 4,318 tests, 34 skips, and zero failures, including inherited upstream tests. This release packages the already-tested installed binary; it does not claim that the deleted development workspace was rebuilt or that all tests were rerun for this documentation/release task. The [case study](../portfolio-case-study.md) separates observed results, failed approaches, implemented-but-unvalidated options, and remaining work.
