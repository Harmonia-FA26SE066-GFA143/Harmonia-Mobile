import Flutter
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AvatarImagePickerPlugin")
    AvatarImagePickerPlugin.register(with: registrar)
    let scoreRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "HarmoniaScoreEngraving")
    scoreRegistrar.register(ScoreEngravingFactory(registrar: scoreRegistrar), withId: "harmonia/score_engraving")
  }
}

private final class AvatarImagePickerPlugin: NSObject, FlutterPlugin, PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
  private static let channelName = "harmonia/avatar_picker"
  private static let maxAvatarBytes = 2 * 1024 * 1024
  private static let maxVoiceBytes = 20 * 1024 * 1024
  private static let maxClipBytes = 100 * 1024 * 1024
  private static let voiceExtensions: Set<String> = ["mp3", "m4a", "wav"]
  private static let evidenceExtensions: Set<String> = ["mp3", "m4a", "wav", "mp4", "mov"]

  private weak var presenter: UIViewController?
  private var pendingResult: FlutterResult?
  private var staffExtensions: Set<String>?
  private var exportingReport = false

  private init(presenter: UIViewController?) {
    self.presenter = presenter
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = AvatarImagePickerPlugin(presenter: registrar.viewController())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard ["pickImage", "pickEvidence", "pickStaffFile", "saveReport"].contains(call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil, let presenter else {
      result(FlutterError(code: "PICKER_BUSY", message: "Image picker is unavailable.", details: nil))
      return
    }

    pendingResult = result
    if call.method == "saveReport" {
      guard let arguments = call.arguments as? [String: Any], let path = arguments["path"] as? String else {
        complete(FlutterError(code: "REPORT_SAVE_FAILED", message: nil, details: nil))
        return
      }
      exportingReport = true
      let picker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: path)], asCopy: true)
      picker.delegate = self
      presenter.present(picker, animated: true)
      return
    }
    if call.method == "pickStaffFile" {
      let arguments = call.arguments as? [String: Any]
      staffExtensions = Set(arguments?["extensions"] as? [String] ?? [])
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
      picker.delegate = self
      presenter.present(picker, animated: true)
      return
    }
    if call.method == "pickEvidence" {
      let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.audio, .movie],
        asCopy: true
      )
      picker.delegate = self
      presenter.present(picker, animated: true)
      return
    }

    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .compatible

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pendingResult = result
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let provider = results.first?.itemProvider else {
      complete(nil)
      return
    }

    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
      guard let self else { return }
      guard let url, error == nil else {
        self.complete(FlutterError(code: "PICKER_FAILED", message: "Could not read the selected image.", details: nil))
        return
      }

      do {
        let image = UIImage(contentsOfFile: url.path)
        guard let image else {
          throw NSError(domain: "AvatarImagePicker", code: 1)
        }
        var quality: CGFloat = 0.88
        var data = image.jpegData(compressionQuality: quality)
        while let current = data, current.count > Self.maxAvatarBytes, quality > 0.38 {
          quality -= 0.1
          data = image.jpegData(compressionQuality: quality)
        }
        guard let data, data.count <= Self.maxAvatarBytes else {
          self.complete(FlutterError(code: "AVATAR_FILE_TOO_LARGE", message: "Avatar images must be 2 MB or smaller.", details: nil))
          return
        }

        let destination = FileManager.default.temporaryDirectory
          .appendingPathComponent("avatar-\(UUID().uuidString).jpg")
        try data.write(to: destination, options: .atomic)
        self.complete(destination.path)
      } catch {
        self.complete(FlutterError(code: "PICKER_FAILED", message: "Could not process the selected image.", details: nil))
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    complete(nil)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      complete(nil)
      return
    }

    if exportingReport {
      complete(true)
      return
    }

    do {
      let ext = url.pathExtension.lowercased()
      if let allowed = staffExtensions {
        guard allowed.contains(ext) else { throw PickerError(code: "STAFF_FILE_TYPE_NOT_ALLOWED") }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else { throw PickerError(code: "STAFF_FILE_REQUIRED") }
        guard size <= Self.maxVoiceBytes else { throw PickerError(code: "STAFF_FILE_TOO_LARGE") }

        let destination = FileManager.default.temporaryDirectory
          .appendingPathComponent("staff-\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: url, to: destination)
        complete(["path": destination.path, "name": url.lastPathComponent])
        return
      }
      guard Self.evidenceExtensions.contains(ext) else {
        throw PickerError(code: "MEMBER_SKILL_EVIDENCE_TYPE_NOT_ALLOWED")
      }
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
      let maxBytes = Self.voiceExtensions.contains(ext) ? Self.maxVoiceBytes : Self.maxClipBytes
      guard size > 0 else {
        throw PickerError(code: "MEMBER_SKILL_EVIDENCE_REQUIRED")
      }
      guard size <= maxBytes else {
        throw PickerError(code: "MEMBER_SKILL_EVIDENCE_TOO_LARGE")
      }

      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("skill-evidence-\(UUID().uuidString).\(ext)")
      try FileManager.default.copyItem(at: url, to: destination)
      complete(destination.path)
    } catch let error as PickerError {
      complete(FlutterError(code: error.code, message: error.message, details: nil))
    } catch {
      complete(FlutterError(code: "PICKER_FAILED", message: "Could not read the selected file.", details: nil))
    }
  }

  private struct PickerError: Error {
    let code: String
    var message: String { code }
    init(code: String) { self.code = code }
  }

  private func complete(_ value: Any?) {
    DispatchQueue.main.async {
      guard let result = self.pendingResult else { return }
      self.pendingResult = nil
      self.staffExtensions = nil
      self.exportingReport = false
      result(value)
    }
  }
}

private final class ScoreEngravingFactory: NSObject, FlutterPlatformViewFactory {
  private let registrar: FlutterPluginRegistrar

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
      -> FlutterPlatformView {
    ScoreEngravingView(
      frame: frame,
      assetKey: registrar.lookupKey(forAsset: "assets/score/index.html"),
      channel: FlutterMethodChannel(
        name: "harmonia/score_engraving/\(viewId)", binaryMessenger: registrar.messenger()
      )
    )
  }
}

private final class ScoreStatusHandler: NSObject, WKScriptMessageHandler {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    if message.frameInfo.isMainFrame, let status = message.body as? String {
      channel.invokeMethod("status", arguments: status)
    }
  }
}

private final class ScoreEngravingView: NSObject, FlutterPlatformView, WKNavigationDelegate {
  private let web: WKWebView
  private let channel: FlutterMethodChannel
  private let asset: URL?

  init(frame: CGRect, assetKey: String, channel: FlutterMethodChannel) {
    self.channel = channel
    asset = Bundle.main.url(forResource: assetKey, withExtension: nil)
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.userContentController.add(ScoreStatusHandler(channel: channel), name: "scoreStatus")
    web = WKWebView(frame: frame, configuration: config)
    super.init()
    web.navigationDelegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "SCORE_VIEW_CLOSED", message: nil, details: nil))
        return
      }
      switch call.method {
      case "start":
        guard let asset else {
          result(FlutterError(code: "SCORE_ASSET_MISSING", message: nil, details: nil))
          return
        }
        web.loadFileURL(asset, allowingReadAccessTo: asset.deletingLastPathComponent())
        result(nil)
      case "evaluate":
        guard let script = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        web.evaluateJavaScript(script) { _, error in
          result(error == nil ? nil : FlutterError(code: "SCORE_RENDER_FAILED", message: nil, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func webView(
    _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    let allowed = action.request.url?.standardizedFileURL == asset?.standardizedFileURL
    decisionHandler(allowed ? .allow : .cancel)
  }

  func view() -> UIView { web }

  deinit {
    channel.setMethodCallHandler(nil)
    web.configuration.userContentController.removeScriptMessageHandler(forName: "scoreStatus")
    web.stopLoading()
  }
}
