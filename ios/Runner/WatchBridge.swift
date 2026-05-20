import Flutter
import WatchConnectivity

final class WatchBridge: NSObject {
    private var eventSink: FlutterEventSink?

    func setup(messenger: FlutterBinaryMessenger) {
        FlutterMethodChannel(name: "co.yanev.fitnessApp/watch", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "syncTemplates":
                    let args = call.arguments as? [String: Any]
                    self?.pushTemplates(json: args?["templates"] as? String ?? "")
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

        FlutterEventChannel(name: "co.yanev.fitnessApp/watch_events", binaryMessenger: messenger)
            .setStreamHandler(self)

        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func pushTemplates(json: String) {
        let s = WCSession.default
        guard s.activationState == .activated else { return }
        try? s.updateApplicationContext(["action": "sync_templates", "data": json])
    }

    private func emit(_ event: [String: Any]) {
        DispatchQueue.main.async { self.eventSink?(event) }
    }
}

// MARK: - FlutterStreamHandler

extension WatchBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - WCSessionDelegate

extension WatchBridge: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        emit(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        emit(message)
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        emit(userInfo)
    }
}
