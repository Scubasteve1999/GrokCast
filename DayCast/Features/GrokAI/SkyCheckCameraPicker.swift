import SwiftUI
import UIKit

/// In-flow rear camera for Sky Check. JPEG bytes go to the same pending-image
/// hop as `PhotosPicker`. Never present this when the camera is unavailable
/// (iPhone Simulator) — `SkyCheckCameraGate` must fail first.
struct SkyCheckCameraPicker: UIViewControllerRepresentable {
  var onCapture: (Data?) -> Void
  var onCancel: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onCapture: onCapture, onCancel: onCancel)
  }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.allowsEditing = false
    picker.mediaTypes = ["public.image"]
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
      DispatchQueue.main.async { onCancel() }
      return picker
    }
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    return picker
  }

  func updateUIViewController(
    _ uiViewController: UIImagePickerController, context: Context
  ) {
    context.coordinator.onCapture = onCapture
    context.coordinator.onCancel = onCancel
  }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
  {
    var onCapture: (Data?) -> Void
    var onCancel: () -> Void

    init(onCapture: @escaping (Data?) -> Void, onCancel: @escaping () -> Void) {
      self.onCapture = onCapture
      self.onCancel = onCancel
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      onCancel()
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      let image = info[.originalImage] as? UIImage
      onCapture(image?.jpegData(compressionQuality: 0.9))
    }
  }
}
