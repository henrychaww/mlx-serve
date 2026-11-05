# Managed Media for MLX-Serve

One Mac interface for native MLX models, SeedVR2 image upscaling, and LTX 2.5 GGUF video with generated audio.

This is a personal Apple Silicon integration fork of [David Dalcu's MLX-Serve](https://github.com/ddalcu/mlx-serve). It keeps the existing application and adds application-managed external media processes. It does not claim authorship of the upstream app, model architectures, or inference runtimes.

**[Download the portfolio preview](https://github.com/henrychaww/mlx-serve/releases/tag/managed-media-preview-2026.11.06.1) · [Engineering case study](docs/portfolio-case-study.md) · [Validation record](docs/external-media-integration.md) · [Release prerequisites](docs/releases/managed-media-preview-2026.11.06.1.md)**

## What this fork adds

| Area | Integration | Verified outcome |
|---|---|---|
| Image upscaling | SeedVR2 through MLX-Gen | In-app download, selection, and 4× upscaling from 256×256 to 1024×1024 using 7B 8-bit |
| GGUF video | LTX 2.5 through a patched stable-diffusion.cpp | In-app download and companion detection; text-to-video with an audio track |
| Video playback | Managed FFmpeg conversion and the existing native player | Generated AVI converted to H.264/AAC MP4; decoded frames visible in the app |
| Process lifecycle | App-owned headless engines | Start on demand, serialize external jobs, and handle cancellation and app quit |
| Memory coordination | Admission check and app-local reservation | Reject insufficient memory; block app-initiated local model loads/chat during an external job |
| Storage | Read models in place, reuse compatible components | No model copies into engine directories; no weights in this repository or release |

The tested model choices are [SeedVR2 7B 8-bit](https://huggingface.co/AbstractFramework/seedvr2-7b-8bit) and [LTX 2.5 uncensored v1.1](https://huggingface.co/frtertaer/LTX-2.5-uncensored-v1.1-FP8), selecting its **Q4_K_M GGUF** transformer. The repository name includes FP8, but the tested file is GGUF Q4_K_M. “Uncensored” is the publisher's label; a refusal rate was not measured.

## Evidence and scope

The working personal build was installed on a MacBook Pro with an Apple M5 Pro, 64 GB unified memory, and a 2 TB SSD. The final recorded Swift suite contained **4,318 tests, 34 skipped, and zero failures**. This is the full inherited-plus-integration suite, not 4,318 tests written for this fork. Live checks covered the external workflows and representative existing chat, image, sound, speech, decision, and 3D generation paths.

The installed build also completed a fresh GGUF video job, automatically converted it, and displayed its decoded frame in the same interface. Following removal of the development directories, app startup, engine startup, a small Metal computation, and video conversion passed again.

These are functional checks, not a model-quality benchmark. A 512×512, 33-frame, four-step video test took over four minutes for roughly two seconds of output. **4K/8K performance, long clips, exact refusal rates, other hardware, and a fresh-machine installer are not validated.**

## Release status

The release contains the **Apple Silicon Mac app**, build provenance, and checksums. It does **not** contain models, the MLX-Gen Python environment, stable-diffusion.cpp, FFmpeg, or their external prerequisites. Existing installations with the documented runtimes can use the app; a new machine needs runtime provisioning. See the [release guide](docs/releases/managed-media-preview-2026.11.06.1.md).

The application is an **ad-hoc signed personal build**, not an Apple-notarized distribution. Its declared minimum is macOS 26.2; compatibility across that whole OS range has not been tested. The release audit machine reports macOS 27.0.1. No instructions to disable macOS security controls are provided.

The built-in updater still targets `ddalcu/mlx-serve`. An upstream update can replace this fork's integration. Use this repository's release page to identify this preview; it has not gained a separate updater channel.

## Read the engineering work

- [Case study: architecture, decisions, failures, results, and next steps](docs/portfolio-case-study.md)
- [Detailed integration and validation record](docs/external-media-integration.md)
- [Runtime prerequisites and reproduction boundaries](docs/releases/managed-media-preview-2026.11.06.1.md)
- [GGML mixed-precision patch](patches/stable-diffusion-ggml-mixed-precision.patch) and [arithmetic regression checks](patches/ggml-mixed-precision-test.cpp)
- [Upstream-oriented project reference](README.upstream.md), including the original project's installation and feature documentation

## Attribution

The integration builds on [MLX-Serve](https://github.com/ddalcu/mlx-serve), [MLX-Gen](https://github.com/lpalbou/mlx-gen), its [mflux foundation](https://github.com/filipstrand/mflux), [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp), [ggml](https://github.com/leejet/ggml), [MLX](https://github.com/ml-explore/mlx), and [FFmpeg](https://ffmpeg.org/). Model authors and checkpoint packagers retain their own rights and licenses. This fork's scope is integration and validation, not model training. Existing [LICENSE](LICENSE), [LICENSE-APACHE-2.0](LICENSE-APACHE-2.0), and [NOTICE](NOTICE) files remain in place and in the app bundle.
