# External media integration

This prototype adds on-demand SeedVR2 upscaling through MLX-Gen and LTX 2.5 GGUF video through stable-diffusion.cpp. It does not add support for arbitrary GGUF, image, video, audio, or 3D model architectures. Model weights are read from their existing paths; the application does not copy them into runtime folders.

The runtimes currently installed on the test Mac are:

- `~/.mlx-serve/runtimes/mlx-gen/.venv/bin/mlxgen`, based on MLX-Gen revision `99fb94dd3eaa9dd1931cd3cd8eae1ae3e20f2ef3`.
- `~/.mlx-serve/runtimes/stable-diffusion/bin/sd-cli`, built from stable-diffusion.cpp revision `58bb3c1b1cd4749e94e39f537e9adfce295dcaee`, ggml revision `135ce1e0e3f2b0693d3de93d4f6b5fa0a1947820`, with `patches/stable-diffusion-ggml-mixed-precision.patch` applied inside its ggml submodule. The patch has a regression test in `patches/ggml-mixed-precision-test.cpp`.

These are local, externally installed runtimes. The Python environment relies on the existing Homebrew Python installation; sd-cli links to Homebrew WebP libraries. The app reports a missing executable rather than automatically installing these dependencies.

An isolated app workflow searched Hugging Face for SeedVR2 3B 4-bit, downloaded it through the app, selected it in the image model menu, accepted a 64×64 image, and produced a 128×128 PNG through its upscaling controls. The test model and output were temporary and removed afterwards.

The tested LTX path uses the uncensored Q4 GGUF transformer and Q4 text encoder, the pack's audio VAE, and the standard LTX 2.5 convolutional video VAE. In the isolated app, selecting the discovered model also found all three supporting files. It produced playable AVIs with video and audio in two tests: 256×256, nine frames and one step; and 512×512, 33 frames and four steps. The second test took over four minutes for a 2.06-second clip on the test Mac. These are functional checks, not a video-quality or refusal-rate evaluation. The temporary models and videos were removed.

Hugging Face search in the isolated app showed SeedVR2 under the MLX filter and the uncensored LTX repository under GGUF, with Q4, Q6 and Q8 choices. Download-manager tests using a simulated origin cover the SeedVR2 component transfer and LTX component transfers across both repositories. An actual LTX download through the app's UI has not been tested end to end.

During GGUF video generation, the interface displays recognized loading, generation, and decoding stages without displaying raw engine logs. These are stages, not a percentage or time estimate.

The app blocks its own explicit model-load requests and local chat starts while an external media process owns the memory reservation; remote chat remains available. Before a job it compares available memory against the selected weights plus a 25% or 2 GiB buffer, whichever is larger. This is a minimum admission check, not a prediction of peak memory at every resolution. Other processes or external clients can still load models after the check, so this is not a system-wide memory lock.

An isolated UI check with an oversized sparse fixture showed the memory refusal and confirmed that the engine was not started. Managed-process tests cover both admission and rejection without loading a real model.

The rebuilt personal bundle's isolated server, reading the existing model library without copying weights, returned a chat response, a WAV sound effect, and a Qwen-Image 2.1 image at 256×256 with one step. A fresh isolated Hunyuan3D check returned a GLB with 74,992 vertices (eight steps, octree resolution 128). Qwen3-TTS 1.7B bf16 returned a WAV and d1 returned typed decision answers. These are functional checks, not output-quality evaluations or exhaustive tests of every model.

Personal installation uses the project's supported ad-hoc development build, which does not require an Apple Developer ID. It is not a notarized release and does not carry the vendor release's hardened-runtime signature; changing its signing identity may require macOS permissions to be granted again. Earlier experiments trying to retain hardened runtime with ad-hoc or local self-signed identities failed library validation. Those failures do not prevent the supported development build from launching. No Gatekeeper, SIP, FileVault, TCC, keychain trust, or quarantine settings are changed. Packaging removes only signing-incompatible Finder metadata, preserving quarantine and other extended attributes, and accepts `SWIFT_SCRATCH_PATH` to reuse existing build artifacts.

The optimized personal bundle was built using `APP_ONLY=1 SWIFT_SCRATCH_PATH=/tmp/mlx-serve-swift-build APPLE_DEVELOPER_ID=- APPLE_TEAM_ID=- SKIP_NOTARIZE=1 bash app/build.sh`. Its Swift interface uses the release configuration and the inference server is ReleaseFast. `APP_ONLY` stops after bundle verification, avoiding unused installer archives. Bundle signature verification and isolated launch succeeded, with the upscaler and GGUF video panes accessible. This alone does not establish every feature or OS permission has been tested.

[Upstream PR #248](https://github.com/ddalcu/mlx-serve/pull/248), reviewed at head `39d5541e26d9415461530f17f5e803d3898ca6d1`, is a separate native SeedVR2 implementation. It was closed without merging. Its author's notes explicitly leave video restoration and several weight variants untested. The native VAE's memory constants cannot be applied to our different MLX-Gen implementation without measurement, so the PR is a reference rather than an imported patch. Our current weight-based admission floor still does not guarantee that arbitrary output resolutions fit.

The original signed server was also tested with a locally built example media plugin in an isolated home directory. It loaded the plugin and listed its fixture model; a separate marker-gated probe also appeared in the registry as an `AudioVideo` model. The original app can map that architecture to its LTX video family, but that family's UI also checks for the native LTX bundle's files. This is not evidence that a runner plugin works in the existing app: no MLX-Gen or stable-diffusion.cpp plugin was built, the default bundle checks and in-app discovery remain unresolved, and no probe was installed into the user's normal configuration.

The subsequent permanent SeedVR2 7B 8-bit download completed through the app in the existing model library. The optimized app generated a valid, nonblank 1024×1024 PNG from a 256×256 input at 4×, and showed completion after navigating away and back. The child process exited. This does not establish performance or memory requirements at 4K or 8K.
