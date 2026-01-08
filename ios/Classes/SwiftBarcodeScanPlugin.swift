import Flutter
import UIKit
import SwiftProtobuf
import AVFoundation

public class SwiftBarcodeScanPlugin: NSObject, FlutterPlugin, BarcodeScannerViewControllerDelegate {

    private var result: FlutterResult?
    private var hostViewController: UIViewController?
    private var presentedNavigationController: UINavigationController?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "de.mintware.barcode_scan", binaryMessenger: registrar.messenger())
        let instance = SwiftBarcodeScanPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.result = result
        if ("scan" == call.method) {
            let configuration: Configuration? = getPayload(call: call)
            showBarcodeView(config: configuration)}
        else if ("numberOfCameras" == call.method) {
            result(AVCaptureDevice.devices(for: .video).count)
        } else if ("requestCameraPermission" == call.method) {
            result(false)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func showBarcodeView(config: Configuration? = nil) {
        if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
            hostViewController = topViewController(base: rootVC)
        } else if let window = UIApplication.shared.delegate?.window, let rootVC = window?.rootViewController {
            hostViewController = topViewController(base: rootVC)
        }

        let scannerViewController = BarcodeScannerViewController()

        let navigationController = UINavigationController(rootViewController: scannerViewController)
        navigationController.modalPresentationStyle = .fullScreen

        if let config = config {
            scannerViewController.config = config
        }
        scannerViewController.delegate = self

        presentedNavigationController = navigationController
        hostViewController?.present(navigationController, animated: false)
    }

    private func dismissScanner(completion: @escaping () -> Void) {
        guard let navController = presentedNavigationController else {
            completion()
            return
        }
        presentedNavigationController = nil
        navController.presentingViewController?.dismiss(animated: false, completion: completion)
    }
    
    private func getPayload<T : SwiftProtobuf.Message>(call: FlutterMethodCall) -> T? {
        
        if(call.arguments == nil || !(call.arguments is FlutterStandardTypedData)) {
            return nil
        }
        do {
            let configuration = try T(serializedData: (call.arguments as! FlutterStandardTypedData).data)
            return configuration
        } catch {
        }
        return nil
    }
    
    func didScanBarcodeWithResult(_ controller: BarcodeScannerViewController?, scanResult: ScanResult) {
        dismissScanner { [weak self] in
            do {
                self?.result?(try scanResult.serializedData())
            } catch {
                self?.result?(FlutterError(code: "err_serialize", message: "Failed to serialize the result", details: nil))
            }
        }
    }

    func didFailWithErrorCode(_ controller: BarcodeScannerViewController?, errorCode: String) {
        dismissScanner { [weak self] in
            self?.result?(FlutterError(code: errorCode, message: nil, details: nil))
        }
    }
    
    private func topViewController(base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)

        } else if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)

        } else if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

