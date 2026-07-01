import CoreImage
import Foundation

struct QRCodeRecognizer {
    private let detector: CIDetector?

    init() {
        detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
    }

    func detectStrings(in imageData: Data) -> [String] {
        guard
            let ciImage = CIImage(data: imageData),
            let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        else {
            return []
        }

        var results: [String] = []
        for feature in features {
            guard let message = feature.messageString, !message.isEmpty else { continue }
            if !results.contains(message) {
                results.append(message)
            }
        }
        return results
    }
}
