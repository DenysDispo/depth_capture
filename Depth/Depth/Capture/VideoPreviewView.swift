import UIKit
import AVFoundation

final class VideoPreviewView: UIView {

  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }

  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    guard let layer = layer as? AVCaptureVideoPreviewLayer else {
      fatalError()
    }

    return layer
  }

  var session: AVCaptureSession? {
    get {
      videoPreviewLayer.session
    }
    set {
      videoPreviewLayer.session = newValue
    }
  }
}
