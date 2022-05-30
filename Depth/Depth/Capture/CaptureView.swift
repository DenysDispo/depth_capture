import UIKit
import SnapKit
import AVFoundation

final class CaptureView: UIView {

  var session: AVCaptureSession? {
    get {
      videoPreviewView.session
    }

    set {
      videoPreviewView.session = newValue
    }
  }

  var capture: (() -> Void)?

  private lazy var captureButton: UIButton = {
    let button = UIButton()
    button.addTarget(self, action: #selector(onCaptureButtonTouchUp), for: .touchUpInside)
    button.backgroundColor = .white
    button.layer.cornerRadius = 25
    button.layer.borderWidth = 1
    button.layer.borderColor = UIColor.black.cgColor
    return button
  }()

  private lazy var videoPreviewView = VideoPreviewView()

  init() {
    super.init(frame: .zero)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func set(videoOrientation: AVCaptureVideoOrientation) {
    videoPreviewView.videoPreviewLayer.connection?.videoOrientation = videoOrientation
  }

  private func setup() {
    setupPreviewView()
    setupCaptureButton()
  }

  private func setupPreviewView() {
    addSubview(videoPreviewView)

    videoPreviewView.snp.makeConstraints {
      $0.verticalEdges.horizontalEdges.equalToSuperview()
    }
  }

  private func setupCaptureButton() {
    addSubview(captureButton)

    captureButton.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.bottom.equalToSuperview().inset(60)
      $0.width.height.equalTo(50)
    }
  }

  @objc
  private func onCaptureButtonTouchUp() {
    capture?()
  }
}
