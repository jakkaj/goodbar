import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var screenService: ScreenService?
  
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    // Register custom method channels
    registerMethodChannels(flutterViewController: flutterViewController)

    super.awakeFromNib()
  }
  
  private func registerMethodChannels(flutterViewController: FlutterViewController) {
    let screenChannel = FlutterMethodChannel(
      name: "com.goodbar/screen_service",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    
    screenService = ScreenService(channel: screenChannel)
    
    screenChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.screenService?.handle(call, result: result)
    }
  }
}
