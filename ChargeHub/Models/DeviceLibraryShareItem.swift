import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DeviceLibraryShareItem: Transferable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(item.filename)
                .appendingPathExtension("json")

            try item.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
