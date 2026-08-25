import SwiftUI
import Testing

@MainActor
struct SondeDeRendu {
    @Test("Sonde temporaire de rendu")
    func rendu() {
        let vue = ZStack {
            Color.blue
            Text("Yum")
        }
        .frame(width: 80, height: 40)

        let rendu = ImageRenderer(content: vue)
        rendu.scale = 1

        #expect(rendu.cgImage != nil)

        if let image = rendu.cgImage {
            print("SONDE \(image.width)x\(image.height)")
        }
    }
}
