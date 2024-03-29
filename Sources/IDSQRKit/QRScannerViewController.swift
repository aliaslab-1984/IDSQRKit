//
//  QRScannerViewController.swift
//  IDSignQRGenerator
//
//  Created by Francesco Bianco on 28/12/21.
//

import Foundation
import AVKit

#if os(iOS)
import UIKit
import ALConstraintKit

public final class QRCapturerViewController: UIViewController {
    
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var qrCodeFrameView: UIView?
    
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer(target: self, action: #selector(toggleSession))
        return gesture
    }()
    
    public let shouldDismissWhenFound: Bool
    
    public lazy var previewView: UIImageView = { [unowned self] in
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            view.image = UIImage(systemName: "qrcode.viewfinder")
        }
        view.isUserInteractionEnabled = true
        
        if #available(iOS 13.0, *) {
            view.tintColor = .secondarySystemFill
        } else {
            // Fallback on earlier versions
            view.tintColor = .lightGray
        }
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .darkGray
        return view
    }()
    
    public init(shouldDismiss: Bool) {
        self.shouldDismissWhenFound = shouldDismiss
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var qROutput: String?
    
    public weak var delegate: QRDataSource?
    public weak var eventLoger: QREventLogger?
    
    private var windowInterfaceOrientation: UIInterfaceOrientation? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
        } else {
            return UIApplication.shared.statusBarOrientation
        }
    }

    // MARK: UI Components
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        videoPreviewLayer?.frame = previewView.layer.bounds
        
        guard let windowInterfaceOrientation = self.windowInterfaceOrientation else { return }
        updateVideoOrientation(using: windowInterfaceOrientation)
    }
    
    public override func loadView() {
        super.loadView()
        
        view.addSubviews([previewView])
        
        previewView.mirrorVConstraints(from: self)
        previewView.mirrorHConstraints(from: self)
        previewView.addGestureRecognizer(tapGestureRecognizer)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            self.view.backgroundColor = .systemBackground
        } else {
            self.view.backgroundColor = .white
        }
        
        if self.isModal {
            if #available(iOS 13.0, *) {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))
                self.navigationController?.navigationBar.standardAppearance.configureWithTransparentBackground()
                self.overrideUserInterfaceStyle = .dark
            } else {
                // Fallback on earlier versions
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
            }
        }
        
        switch QRCameraAccess.hasPermission() {
        case .authorized:
            setup()
            setupGreenBox()
        case .notDetermined:
            if #available(iOS 13.0, *) {
                previewView.image = UIImage(systemName: "video.slash.fill")
            }
            
            let alert = Alerts.permissionAlert { [weak self] in
                self?.setup()
                self?.setupGreenBox()
                self?.previewView.image = nil
                self?.previewView.backgroundColor = nil
                self?.viewDidLayoutSubviews()
                self?.resume()
            } onDenied: { [weak self] in
                self?.dismiss(animated: true)
            }
            
            alert.view.tintColor = self.view.tintColor
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.present(alert, animated: true)
            }
        case .denied, .restricted:
            let settingsAlert = Alerts.settingsAlert { [weak self] in
                self?.dismiss(animated: true)
            }
            settingsAlert.view.tintColor = self.view.tintColor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.present(settingsAlert, animated: true)
            }
        @unknown default:
            let settingsAlert = Alerts.settingsAlert { [weak self] in
                self?.dismiss(animated: true)
            }
            settingsAlert.view.tintColor = self.view.tintColor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.present(settingsAlert, animated: true)
            }
        }
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.eventLoger?.qrEventOccurred(event: "Stopped capture session.", level: .info)
        }
    }
    
    private func updateVideoOrientation(using orientation: UIInterfaceOrientation) {
        eventLoger?.qrEventOccurred(event: "Switched video orientation to \(orientation)).", level: .info)
        self.videoPreviewLayer?.connection?.videoOrientation = orientation.toAVPreviewOrientation
    }

    public func resume() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            self?.eventLoger?.qrEventOccurred(event: "Resuming capture session.", level: .info)
        }
        qrCodeFrameView?.frame = .zero
    }
    
    @objc private func close() {
        // It's better to notify the delegate once the window gets closed instead of the moment when the qr gets parsed.
        self.dismiss(animated: true) { [weak self] in
            guard let qrString = self?.qROutput else {
                return
            }
            self?.delegate?.didGet(qrData: qrString)
        }
    }
    
    @objc private func toggleSession() {
        guard let session = captureSession else {
            return
        }
        if session.isRunning {
            session.stopRunning()
        } else {
            session.startRunning()
        }
    }
    
    private func setup() {
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video
        // as the media type parameter.
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
         
        // Get an instance of the AVCaptureDeviceInput class using the previous device object.
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {return}
         
        // Initialize the captureSession object.
        let session = AVCaptureSession()
        captureSession = session
        // Set the input device on the capture session.
        session.addInput(input as AVCaptureInput)
        
        let captureMetadataOutput = AVCaptureMetadataOutput()
        session.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        initializePreviewLayer(with: session)
    }
    
    private func initializePreviewLayer(with session: AVCaptureSession) {
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        let videoLayer = AVCaptureVideoPreviewLayer(session: session)
        videoPreviewLayer = videoLayer
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoLayer.frame = previewView.bounds
        previewView.layer.addSublayer(videoLayer)
        updateVideoOrientation(using: windowInterfaceOrientation ?? .portrait)
    }
    
    private func setupGreenBox() {
        // Initialize QR Code Frame to highlight the QR code
        // swiftlint:disable force_unwrapping
        qrCodeFrameView = UIView()
        qrCodeFrameView?.layer.borderColor = UIColor.green.cgColor
        qrCodeFrameView?.layer.borderWidth = 2
        qrCodeFrameView?.layer.cornerRadius = 12
        qrCodeFrameView?.layer.masksToBounds = true
        previewView.addSubview(qrCodeFrameView!)
        previewView.bringSubviewToFront(qrCodeFrameView!)
        // swiftlint:enable force_unwrapping
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Start video capture.
            self?.captureSession?.startRunning()
            self?.eventLoger?.qrEventOccurred(event: "Starting capture session.", level: .info)
        }
    }
}

extension QRCapturerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.isEmpty {
            qrCodeFrameView?.frame = .zero
            // messageLabel.text = "No QR code is detected"
            eventLoger?.qrEventOccurred(event: "No QR detected!", level: .warning)
            return
        }
            
        // Get the metadata object.
        guard let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject else {
            return
        }
            
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            guard let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj as AVMetadataMachineReadableCodeObject) as? AVMetadataMachineReadableCodeObject else {
                return
            }
            qrCodeFrameView?.frame = barCodeObject.bounds
            
            if metadataObj.stringValue != nil {
                self.qROutput = metadataObj.stringValue
                self.captureSession?.stopRunning()
                
                eventLoger?.qrEventOccurred(event: "A QR has been decoded! It's \(metadataObj.stringValue?.count ?? 0) characters long.", level: .info)
                
                if shouldDismissWhenFound {
                    self.close()
                } else {
                    delegate?.didGet(qrData: metadataObj.stringValue ?? "")
                }
            }
        }
    }
}

extension UIViewController {

    var isModal: Bool {

        let presentingIsModal = presentingViewController != nil
        let presentingIsNavigation = navigationController?.presentingViewController?.presentedViewController == navigationController
        let presentingIsTabBar = tabBarController?.presentingViewController is UITabBarController

        return presentingIsModal || presentingIsNavigation || presentingIsTabBar
    }
    
}

extension UIDeviceOrientation {
    
    var toAVPreviewOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .faceUp, .faceDown, .unknown:
            return .portrait
        @unknown default:
            return .portrait
        }
    }
    
}

extension UIInterfaceOrientation {
    
    var toAVPreviewOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .unknown:
            return .portrait
        @unknown default:
            return .portrait
        }
    }
    
}

#endif
