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
    
    let shouldDismissWhenFound: Bool
    
    lazy var previewView: UIImageView = { [unowned self] in
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
    
    init(shouldDismiss: Bool) {
        self.shouldDismissWhenFound = shouldDismiss
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var qROutput: String?
    
    weak var delegate: QRDataSource?

    // MARK: UI Components
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let layer = videoPreviewLayer {
            layer.frame = previewView.layer.bounds
            previewView.layer.addSublayer(layer)
        }
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
        
        setup()
        setupGreenBox()
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
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.captureSession?.stopRunning()
    }

    public func resume() {
        captureSession?.startRunning()
        qrCodeFrameView?.frame = .zero
    }
    
    private func setup() {
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video
        // as the media type parameter.
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
         
        // Get an instance of the AVCaptureDeviceInput class using the previous device object.
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {return}
         
        // Initialize the captureSession object.
        captureSession = AVCaptureSession()
        // Set the input device on the capture session.
        captureSession?.addInput(input as AVCaptureInput)
        
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession?.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        initializePreviewLayer()
    }
    
    private func initializePreviewLayer() {
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        if let session = captureSession {
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
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
        // Start video capture.
        captureSession?.startRunning()
    }
}

extension QRCapturerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.isEmpty {
            qrCodeFrameView?.frame = .zero
            // messageLabel.text = "No QR code is detected"
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
#endif
