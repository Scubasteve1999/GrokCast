import CoreTransferable
import UniformTypeIdentifiers

/// PNG payload for Sky Check community photo sharing.
struct StormSpotterPhotoShare: Transferable {
  let imageData: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { item in
      item.imageData
    }
  }
}
