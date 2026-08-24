import AVFoundation
import Foundation
import UIKit

/// Camera vs library for Sky Check. Both land on the same pending-image hop —
/// notes sheet, then `analyzeStormPhoto` / `performAdvancedStormAnalysis`.
/// Do not invent a second vision pipeline.
enum SkyCheckPhotoSource: String, Equatable, CaseIterable {
  case camera
  case photoLibrary

  var buttonTitle: String {
    switch self {
    case .camera: SkyCheckDeskCopy.cameraSource
    case .photoLibrary: SkyCheckDeskCopy.librarySource
    }
  }
}

enum SkyCheckPhotoIntake {
  enum Failure: Equatable, Error {
    case couldNotLoad
    case cameraUnavailable
    case cameraDenied

    var userMessage: String {
      switch self {
      case .couldNotLoad: SkyCheckDeskCopy.photoLoadFailed
      case .cameraUnavailable: SkyCheckDeskCopy.cameraUnavailable
      case .cameraDenied: SkyCheckDeskCopy.cameraDenied
      }
    }
  }

  /// Shared hop used by Camera and Photo Library. Empty / missing bytes fail
  /// honestly; valid bytes become `pendingImageData` for the notes sheet.
  static func pendingImage(from data: Data?) -> Result<Data, Failure> {
    guard let data, !data.isEmpty else { return .failure(.couldNotLoad) }
    return .success(data)
  }

  /// iPhone Simulator has no real camera. Even if `UIImagePickerController`
  /// reports a source, Sky Check must not present it — library still works.
  static var isCameraSourceAvailable: Bool {
    #if targetEnvironment(simulator)
      false
    #else
      UIImagePickerController.isSourceTypeAvailable(.camera)
    #endif
  }
}

enum SkyCheckCameraGate: Equatable {
  case ready
  case needsAuthorization
  case unavailable
  case denied

  var failure: SkyCheckPhotoIntake.Failure? {
    switch self {
    case .ready, .needsAuthorization: nil
    case .unavailable: .cameraUnavailable
    case .denied: .cameraDenied
    }
  }

  static func evaluate(
    isSourceAvailable: Bool,
    authorization: AVAuthorizationStatus
  ) -> SkyCheckCameraGate {
    guard isSourceAvailable else { return .unavailable }
    switch authorization {
    case .authorized: return .ready
    case .notDetermined: return .needsAuthorization
    case .denied, .restricted: return .denied
    @unknown default: return .denied
    }
  }
}
