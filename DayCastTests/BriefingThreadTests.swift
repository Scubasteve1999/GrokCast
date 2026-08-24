import UIKit
import XCTest

@testable import DayCast

final class BriefingThreadTests: XCTestCase {
  func testSameCityIdentityDoesNotReplaceTheThread() {
    let seattle = UUID()
    XCTAssertFalse(
      BriefingThreadScope.shouldReplace(boundLocationID: seattle, selectedLocationID: seattle))
    XCTAssertFalse(
      BriefingThreadScope.shouldReplace(boundLocationID: nil, selectedLocationID: nil))
  }

  func testDifferentCityIdentityReplacesTheThread() {
    let seattle = UUID()
    let denver = UUID()
    XCTAssertTrue(
      BriefingThreadScope.shouldReplace(boundLocationID: seattle, selectedLocationID: denver))
    XCTAssertTrue(
      BriefingThreadScope.shouldReplace(boundLocationID: seattle, selectedLocationID: nil))
    XCTAssertTrue(
      BriefingThreadScope.shouldReplace(boundLocationID: nil, selectedLocationID: denver))
  }

  func testPersistedThreadIsNotVisibleOnAnotherCity() throws {
    let store = GrokAIConversationStore(inMemory: true)
    let olive = UUID()
    let seattle = UUID()
    let heat = ChatMessage.assistant(
      "Afternoon heat (96°F, heat index 103°F). Marginal wind risk.")

    try store.saveHistory([heat], for: olive)

    XCTAssertEqual(try store.loadHistory(for: olive).map(\.content), [heat.content])
    XCTAssertTrue(try store.loadHistory(for: seattle).isEmpty)
    XCTAssertTrue(try store.loadHistory(for: nil).isEmpty)
  }

  func testPhotoThumbRoundTripsForTheSameCityOnly() throws {
    let store = GrokAIConversationStore(inMemory: true)
    let olive = UUID()
    let seattle = UUID()
    let original = makeJPEG(width: 2000, height: 1500)
    XCTAssertGreaterThan(original.count, SkyCheckPersistedThumbnail.maxBytes)

    let thumb = original.compressedForVision(
      maxDimension: SkyCheckPersistedThumbnail.maxDimension,
      quality: SkyCheckPersistedThumbnail.jpegQuality
    )
    XCTAssertNotNil(thumb)
    XCTAssertLessThanOrEqual(thumb!.count, SkyCheckPersistedThumbnail.maxBytes)
    XCTAssertLessThan(thumb!.count, original.count)

    let turn = ChatMessage.stormSpotterPhotoTurn(
      locationName: "Olive Branch, MS",
      thumbnail: thumb,
      analysis: "Shelf cloud.",
      notes: nil
    )
    try store.saveHistory([turn.user, turn.assistant], for: olive)

    let oliveLoaded = try store.loadHistory(for: olive)
    XCTAssertEqual(oliveLoaded.count, 2)
    XCTAssertEqual(oliveLoaded[0].role, .user)
    XCTAssertEqual(oliveLoaded[0].content, turn.user.content)
    XCTAssertEqual(oliveLoaded[0].imageData, thumb)
    XCTAssertNotEqual(oliveLoaded[0].imageData, original)
    XCTAssertEqual(oliveLoaded[1].content, "Shelf cloud.")
    XCTAssertNil(oliveLoaded[1].imageData)

    XCTAssertTrue(try store.loadHistory(for: seattle).isEmpty)
    XCTAssertEqual(SkyCheckDeskCopy.photoCTA, "Check this sky")
  }

  func testFullResolutionOriginalIsNotWhatSwiftDataKeeps() throws {
    let store = GrokAIConversationStore(inMemory: true)
    let olive = UUID()
    let original = makeJPEG(width: 2000, height: 1500)
    XCTAssertGreaterThan(original.count, SkyCheckPersistedThumbnail.maxBytes)

    let user = ChatMessage.userWithPhoto(
      text: SkyCheckDeskCopy.photoTurnCaption, imageData: original)
    try store.saveHistory([user], for: olive)

    let loaded = try store.loadHistory(for: olive)
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded[0].content, SkyCheckDeskCopy.photoTurnCaption)
    let stored = loaded[0].imageData
    XCTAssertNotNil(stored)
    XCTAssertNotEqual(stored, original)
    XCTAssertLessThan(stored!.count, original.count)
    XCTAssertLessThanOrEqual(stored!.count, SkyCheckPersistedThumbnail.maxBytes)
    XCTAssertNotNil(UIImage(data: stored!))
  }

  func testLegacyRowWithoutThumbLoadsTextOnly() throws {
    let store = GrokAIConversationStore(inMemory: true)
    let olive = UUID()
    let user = ChatMessage.userWithPhoto(
      text: SkyCheckDeskCopy.photoTurnCaption, imageData: nil)
    let assistant = ChatMessage.assistant("Shelf cloud.")
    try store.saveHistory([user, assistant], for: olive)

    let loaded = try store.loadHistory(for: olive)
    XCTAssertEqual(loaded.map(\.content), [SkyCheckDeskCopy.photoTurnCaption, "Shelf cloud."])
    XCTAssertNil(loaded[0].imageData)
    XCTAssertNil(loaded[1].imageData)
  }

  func testUndecodableThumbIsDroppedAndTextSurvives() throws {
    let store = GrokAIConversationStore(inMemory: true)
    let olive = UUID()
    let user = ChatMessage.userWithPhoto(
      text: SkyCheckDeskCopy.photoTurnCaption,
      imageData: Data([0x00, 0x01, 0x02, 0x03])
    )
    try store.saveHistory([user], for: olive)

    let loaded = try store.loadHistory(for: olive)
    XCTAssertEqual(loaded[0].content, SkyCheckDeskCopy.photoTurnCaption)
    XCTAssertNil(loaded[0].imageData)
  }

  func testOldestThumbsDropOnceTheCityCapIsHit() throws {
    let store = GrokAIConversationStore(inMemory: true)
    let olive = UUID()
    let thumb = makeJPEG(width: 120, height: 80, quality: 0.6)
    XCTAssertLessThanOrEqual(thumb.count, SkyCheckPersistedThumbnail.maxBytes)

    var messages: [ChatMessage] = []
    let extra = 1
    let turns = SkyCheckPersistedThumbnail.maxThumbsPerCity + extra
    let start = Date(timeIntervalSince1970: 1_787_547_600)
    for index in 0..<turns {
      let stamp = start.addingTimeInterval(TimeInterval(index * 2))
      messages.append(
        ChatMessage(
          role: .user,
          content: "sky \(index)",
          timestamp: stamp,
          imageData: thumb
        )
      )
      messages.append(
        ChatMessage(
          role: .assistant,
          content: "ok \(index)",
          timestamp: stamp.addingTimeInterval(1)
        )
      )
    }
    try store.saveHistory(messages, for: olive)

    let loaded = try store.loadHistory(for: olive)
    XCTAssertEqual(loaded.count, turns * 2)
    XCTAssertEqual(loaded[0].content, "sky 0")
    XCTAssertNil(loaded[0].imageData)
    XCTAssertEqual(loaded[2].content, "sky 1")
    XCTAssertEqual(loaded[2].imageData, thumb)
    let lastUser = loaded[loaded.count - 2]
    XCTAssertEqual(lastUser.content, "sky \(turns - 1)")
    XCTAssertEqual(lastUser.imageData, thumb)
    let thumbCount = loaded.compactMap(\.imageData).count
    XCTAssertEqual(thumbCount, SkyCheckPersistedThumbnail.maxThumbsPerCity)
  }

  func testPersistedThumbnailPolicyCompressesAndRejectsGarbage() {
    XCTAssertNil(SkyCheckPersistedThumbnail.jpeg(from: nil))
    XCTAssertNil(SkyCheckPersistedThumbnail.jpeg(from: Data()))
    XCTAssertNil(SkyCheckPersistedThumbnail.jpeg(from: Data([0xFF])))

    let original = makeJPEG(width: 2000, height: 1500)
    XCTAssertGreaterThan(original.count, SkyCheckPersistedThumbnail.maxBytes)
    let jpeg = SkyCheckPersistedThumbnail.jpeg(from: original)
    XCTAssertNotNil(jpeg)
    XCTAssertLessThan(jpeg!.count, original.count)
    XCTAssertLessThanOrEqual(jpeg!.count, SkyCheckPersistedThumbnail.maxBytes)
    XCTAssertNotNil(UIImage(data: jpeg!))
  }

  /// High-frequency fill so JPEG size is not trivially small (a flat gray
  /// 1200×800 compresses under the 32 KB cap and cannot prove we drop originals).
  private func makeJPEG(width: Int, height: Int, quality: CGFloat = 0.95) -> Data {
    let size = CGSize(width: width, height: height)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.jpegData(withCompressionQuality: quality) { context in
      for y in stride(from: 0, to: height, by: 8) {
        for x in stride(from: 0, to: width, by: 8) {
          let v = CGFloat(((x * 13) ^ (y * 29)) & 255) / 255.0
          UIColor(
            red: v,
            green: 1 - v,
            blue: CGFloat((x + y) % 255) / 255.0,
            alpha: 1
          ).setFill()
          context.fill(CGRect(x: x, y: y, width: 8, height: 8))
        }
      }
    }
  }
}
