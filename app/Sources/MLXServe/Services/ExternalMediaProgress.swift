import Foundation

/// Only expose known, non-sensitive engine stages to the interface.
enum ExternalMediaProgress {
    static func stage(in log: String) -> String? {
        let text = log.lowercased()
        let markers = [
            ("loading diffusion model", "Loading model"),
            ("sampling using", "Generating video"),
            ("ltx_audio_vae build", "Decoding audio"),
            ("ltx_video_vae build", "Decoding video"),
            ("decode_first_stage completed", "Finishing video"),
        ]
        return markers.compactMap { marker, label in
            text.range(of: marker, options: .backwards).map { ($0.lowerBound, label) }
        }.max { $0.0 < $1.0 }?.1
    }
}
