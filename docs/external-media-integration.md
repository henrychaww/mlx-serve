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

An isolated server using the existing model library returned a chat response, a WAV sound effect, and a Hunyuan3D GLB with 74,992 vertices. These were functional, low-setting checks; they do not establish output quality or cover every existing model. A Qwen-Image 2.1 check was refused by the server's memory preflight while another local model server was active, so native image generation has not yet passed this regression check.

A replacement distribution must be built and signed without weakening the installed app's security. An ad-hoc hardened build failed to load a bundled framework because the signatures have different Team IDs. The installed developer identity is not available on this Mac. A disposable hardened copy signed with the existing local self-signed code-signing identity also failed to load the framework after its nested libraries were individually re-signed; macOS reported different Team IDs. No keychain trust or macOS security settings were changed. A properly signed release, end-to-end regression checks, and validation of changed macOS permission behavior are still required before replacement.

The original signed server was also tested with a locally built example media plugin in an isolated home directory. It loaded the plugin and listed its fixture model; a separate marker-gated probe also appeared in the registry as an `AudioVideo` model. The original app can map that architecture to its LTX video family, but that family's UI also checks for the native LTX bundle's files. This is not evidence that a runner plugin works in the existing app: no MLX-Gen or stable-diffusion.cpp plugin was built, the default bundle checks and in-app discovery remain unresolved, and no probe was installed into the user's normal configuration.
