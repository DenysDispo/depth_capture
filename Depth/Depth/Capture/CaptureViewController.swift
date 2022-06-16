import UIKit
import AVKit
import Photos
import UniformTypeIdentifiers

final class CaptureViewController: UIViewController {

  private let session = AVCaptureSession()
  private var deviceInput: AVCaptureDeviceInput!
  private let photoOutput = AVCapturePhotoOutput()

  private var captureView: CaptureView {
    view as! CaptureView
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    requestCameraAccess()
    captureView.session = session
    captureView.capture = { [weak self] in
      guard let self = self else { return }
      let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
      photoSettings.isDepthDataFiltered = true
      photoSettings.isDepthDataDeliveryEnabled = true

      self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
  }

  override func loadView() {
    view = CaptureView()
  }

  private func requestCameraAccess() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      try! self.configureSession()
      session.startRunning()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { isGranted in
        if isGranted {
          DispatchQueue.main.async {
            try! self.configureSession()
            self.session.startRunning()
          }
        }
      }
    default:
      break
    }
  }

  enum DepthCameraError: Error {
    case noDepthDevicesAvailable
    case failedToAddDeviceInput
    case failedToAddPhotoOutput
    case depthDataDeliveryIsNotSupported
  }

  private func configureSession() throws {
    session.beginConfiguration()

    session.sessionPreset = .photo

    let device = try cameraDevice()
    deviceInput = try AVCaptureDeviceInput(device: device)

    if session.canAddInput(deviceInput) {
      session.addInput(deviceInput)

      DispatchQueue.main.async {
        self.captureView.set(videoOrientation: .portrait)
      }
    } else {
      throw DepthCameraError.failedToAddDeviceInput
    }

    if session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)

      guard photoOutput.isDepthDataDeliverySupported else {
        throw DepthCameraError.depthDataDeliveryIsNotSupported
      }
      photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
    } else {
      throw DepthCameraError.failedToAddPhotoOutput
    }

    session.commitConfiguration()
  }

  private func cameraDevice() throws -> AVCaptureDevice {
    if let dualWideCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
      return dualWideCameraDevice
    } else if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
      return dualCameraDevice
    } else {
      throw DepthCameraError.noDepthDevicesAvailable
    }
  }
}

extension CaptureViewController: AVCapturePhotoCaptureDelegate {

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    process(photo: photo)

    let alertController = UIAlertController(title: "Saved", message: "Saved to library", preferredStyle: .alert)
    alertController.addAction(.init(title: "OK", style: .default))
    present(alertController, animated: true)
  }

  private func process(photo: AVCapturePhoto) {
    guard
      let photoData = photo.fileDataRepresentation(),
      let depthData = photo.depthData,
      let imageSource = CGImageSourceCreateWithData(photoData as CFData, nil)
    else { return }

    let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
    guard
      let propertiesDictionary = properties as? [CFString: Any],
      let orientationRawValue = propertiesDictionary[kCGImagePropertyOrientation] as? UInt32,
      let orientation = CGImagePropertyOrientation(rawValue: orientationRawValue)
    else { return }

    let depthMap = depthData
      .converting(toDepthDataType: kCVPixelFormatType_DisparityFloat16)
      .applyingExifOrientation(orientation)
      .depthDataMap

    let normalizedDepthData = try! depthData.replacingDepthDataMap(with: depthMap)

    guard
      let jpegData = UIImage(data: photoData)?.jpegData(compressionQuality: 1.0),
      let jpegImage = UIImage(data: jpegData)
    else { return }

    guard
      let data = attach(depthData: normalizedDepthData, to: jpegImage, orientation: orientationRawValue)
    else { return }

    PHPhotoLibrary.requestAuthorization { status in
      if status == .authorized {
        PHPhotoLibrary.shared().performChanges({
          let options = PHAssetResourceCreationOptions()
          let creationRequest = PHAssetCreationRequest.forAsset()
          creationRequest.addResource(with: .photo, data: data, options: options)
        })
      }
    }
  }

  private func attach(depthData: AVDepthData, to JPEGImage: UIImage, orientation: UInt32) -> Data? {
    guard
      let ciJPEGImage = CIImage(image: JPEGImage, options: [
        .applyOrientationProperty: true,
        .properties: [kCGImagePropertyOrientation: orientation]
      ]),
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    else { return nil }
    let context = CIContext()
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("image_depth.jpeg")

    try! context.writeJPEGRepresentation(
      of: ciJPEGImage,
      to: path,
      colorSpace: colorSpace,
      options: [CIImageRepresentationOption.avDepthData: depthData]
    )

    let data = try! Data(contentsOf: path)
    try! FileManager.default.removeItem(at: path)
    return data
  }
}
