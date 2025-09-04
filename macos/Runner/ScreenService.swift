import Cocoa
import FlutterMacOS

/// Handles screen/display related operations for the Flutter app.
/// 
/// Provides access to NSScreen APIs for querying display configuration
/// and monitoring display changes.
class ScreenService: NSObject {
    private let channel: FlutterMethodChannel
    private var displayObserver: Any?
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        setupDisplayChangeObserver()
    }
    
    deinit {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getDisplays":
            getDisplays(result: result)
        case "getDisplay":
            guard let args = call.arguments as? [String: Any],
                  let displayId = args["displayId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                   message: "displayId is required",
                                   details: nil))
                return
            }
            getDisplay(displayId: displayId, result: result)
        case "getPrimaryDisplay":
            getPrimaryDisplay(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func setupDisplayChangeObserver() {
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDisplayChange()
        }
    }
    
    private func handleDisplayChange() {
        let displays = NSScreen.screens.map { displayToDictionary($0) }
        let event: [String: Any] = [
            "displays": displays,
            "changeType": "reconfigured"
        ]
        channel.invokeMethod("onDisplaysChanged", arguments: event)
    }
    
    private func getDisplays(result: FlutterResult) {
        let displays = NSScreen.screens.map { displayToDictionary($0) }
        result(displays)
    }
    
    private func getDisplay(displayId: String, result: FlutterResult) {
        guard let displayIdInt = Int(displayId) else {
            result(FlutterError(code: "INVALID_ID",
                              message: "Invalid display ID format",
                              details: nil))
            return
        }
        
        let screen = NSScreen.screens.first { screen in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int
            return screenNumber == displayIdInt
        }
        
        if let screen = screen {
            result(displayToDictionary(screen))
        } else {
            result(nil)
        }
    }
    
    private func getPrimaryDisplay(result: FlutterResult) {
        if let mainScreen = NSScreen.main {
            result(displayToDictionary(mainScreen))
        } else {
            result(nil)
        }
    }
    
    private func displayToDictionary(_ screen: NSScreen) -> [String: Any] {
        let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? Int ?? 0
        let frame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Convert from Cocoa coordinates (origin bottom-left) to standard (origin top-left)
        // In Cocoa, y=0 is at the bottom of the primary display
        let primaryHeight = NSScreen.main?.frame.height ?? 0
        
        return [
            "id": String(screenNumber),
            "bounds": [
                "x": frame.origin.x,
                "y": primaryHeight - frame.origin.y - frame.height,
                "width": frame.width,
                "height": frame.height
            ],
            "workArea": [
                "x": visibleFrame.origin.x,
                "y": primaryHeight - visibleFrame.origin.y - visibleFrame.height,
                "width": visibleFrame.width,
                "height": visibleFrame.height
            ],
            "scaleFactor": screen.backingScaleFactor,
            "isPrimary": screen == NSScreen.main
        ]
    }
}