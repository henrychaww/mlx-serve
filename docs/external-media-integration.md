# External media integration

This prototype adds on-demand SeedVR2 upscaling through MLX-Gen and LTX 2.5 GGUF video through stable-diffusion.cpp. It does not add support for arbitrary GGUF, image, video, audio, or 3D model architectures. Model weights are read from their existing paths; the application does not copy them into runtime folders.

The runtimes currently installed on the test Mac are:

- `~/.mlx-serve/runtimes/mlx-gen/.venv/bin/mlxgen`, based on MLX-Gen revision `99fb94dd3eaa9dd1931cd3cd8eae1ae3e20f2ef3`.
- `~/.mlx-serve/runtimes/stable-diffusion/bin/sd-cli`, built from stable-diffusion.cpp revision `58bb3c1b1cd4749e94e39f537e9adfce295dcaee`, ggml revision `135ce1e0e3f2b0693d3de93d4f6b5fa0a1947820`, with `patches/stable-diffusion-ggml-mixed-precision.patch` applied inside its ggml submodule. The patch has a regression test in `patches/ggml-mixed-precision-test.cpp`.

These are local, externally installed runtimes. The Python environment relies on the existing Homebrew Python installation; sd-cli links to Homebrew WebP libraries. The app reports a missing executable rather than automatically installing these dependencies.

An isolated app workflow searched Hugging Face for SeedVR2 3B 4-bit, downloaded it through the app, selected it in the image model menu, accepted a 64×64 image, and produced a 128×128 PNG through its upscaling controls. The test model and output were temporary and removed afterwards.

The tested LTX path uses the uncensored Q4 GGUF transformer and Q4 text encoder, the pack's audio VAE, and the standard LTX 2.5 convolutional video VAE. In the isolated app, selecting the discovered model also found all three supporting files. It produced playable AVIs with video and audio in two tests: 256×256, nine frames and one step; and 512×512, 33 frames and four steps. The second test took over four minutes for a 2.06-second clip on the test Mac. These are functional checks, not a video-quality or refusal-rate evaluation. The temporary models and videos were removed.

Hugging Face search in the isolated app showed SeedVR2 under the MLX filter and the uncensored LTX repository under GGUF, with Q4, Q6 and Q8 choices. Download-manager tests using a simulated origin cover the SeedVR2 component transfer and LTX component transfers across both repositories. An actual LTX download through the app's UI has not been tested end to end.

The app blocks its own explicit model-load requests while an external media process owns the memory reservation. Other processes or external clients can still load models independently, so this is not a system-wide memory lock.

A replacement distribution must be built and signed without weakening the installed app's security. An ad-hoc hardened build failed to load a bundled framework because the signatures have different Team IDs. The installed developer identity is not available on this Mac; a properly signed release, end-to-end regression checks, and validation of changed macOS permission behavior are still required before replacement.

The original signed server was also tested with a locally built example media plugin in an isolated home directory. It loaded the plugin and listed its fixture model. This confirms the plugin interface is available, but does not demonstrate an MLX-Gen or stable-diffusion.cpp plugin, in-app downloading, or picker support for a new model family. The probe was not installed into the user's normal MLX-Serve configuration.
