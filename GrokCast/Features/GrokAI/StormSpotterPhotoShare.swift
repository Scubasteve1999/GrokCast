import CoreTransferable
import UniformTypeIdentifiers

/// PNG payload for Storm Spotter community photo sharing.
struct StormSpotterPhotoShare: Transferable {
  let imageData: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { item in
      item.imageData
    }
  }
}
