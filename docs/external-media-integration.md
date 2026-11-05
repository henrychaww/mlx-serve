# External media integration

This prototype adds on-demand SeedVR2 upscaling through MLX-Gen and LTX 2.5 GGUF video through stable-diffusion.cpp. It does not add support for arbitrary GGUF, image, video, audio, or 3D model architectures. Model weights are read from their existing paths; the application does not copy them into runtime folders.

The runtimes currently installed on the test Mac are:

- `~/.mlx-serve/runtimes/mlx-gen/.venv/bin/mlxgen`, based on MLX-Gen revision `99fb94dd3eaa9dd1931cd3cd8eae1ae3e20f2ef3`.
- `~/.mlx-serve/runtimes/stable-diffusion/bin/sd-cli`, built from stable-diffusion.cpp revision `58bb3c1b1cd4749e94e39f537e9adfce295dcaee`, ggml revision `135ce1e0e3f2b0693d3de93d4f6b5fa0a1947820`, with `patches/stable-diffusion-ggml-mixed-precision.patch` applied inside its ggml submodule. The patch has a regression test in `patches/ggml-mixed-precision-test.cpp`.

These are local, externally installed runtimes. The Python environment relies on the existing Homebrew Python installation; sd-cli links to Homebrew WebP libraries. The app reports a missing executable rather than automatically installing these dependencies.

The tested LTX path uses the uncensored Q4 GGUF transformer and Q4 text encoder, the pack's audio VAE, and the standard LTX 2.5 convolutional video VAE. A 256×256, nine-frame, one-step smoke test produced an AVI with video and audio tracks that macOS could open. This is a functional test, not a video-quality or refusal-rate evaluation.

The app blocks its own explicit model-load requests while an external media process owns the memory reservation. Other processes or external clients can still load models independently, so this is not a system-wide memory lock.

A replacement distribution must be built and signed without weakening the installed app's security. An ad-hoc hardened build failed to load a bundled framework because the signatures have different Team IDs. The installed developer identity is not available on this Mac; a properly signed release, end-to-end regression checks, and validation of changed macOS permission behavior are still required before replacement.
