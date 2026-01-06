import SwiftUI
import WebKit
import NearbyInteraction
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var proximityManager = ProximityManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebViewContainer(proximityManager: proximityManager)
                .ignoresSafeArea()
        }
        .onAppear {
            proximityManager.start()
        }
    }
}

// MARK: - WebView Container
struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var proximityManager: ProximityManager

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Add message handler for web -> native communication
        config.userContentController.add(context.coordinator, name: "nativeHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Load the bundled HTML
        if let htmlPath = Bundle.main.path(forResource: "social_beating", ofType: "html") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl.deletingLastPathComponent())
        }

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Push proximity data to web whenever it changes
        let js = "updateNativeProximity(\(proximityManager.nearestDistance), \(proximityManager.peerCount));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: WebViewContainer
        weak var webView: WKWebView?

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Handle messages from web if needed
            if let body = message.body as? [String: Any] {
                print("Message from web: \(body)")
            }
        }
    }
}

// MARK: - Proximity Manager using Nearby Interaction + Multipeer
class ProximityManager: NSObject, ObservableObject {
    @Published var nearestDistance: Float = -1  // -1 = no peer detected
    @Published var peerCount: Int = 0
    @Published var peers: [String: Float] = [:]  // peerID -> distance

    private var niSession: NISession?
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    private var mcBrowser: MCNearbyServiceBrowser?
    private var peerID: MCPeerID!

    private let serviceType = "social-beating"

    private var peerTokens: [MCPeerID: NIDiscoveryToken] = [:]

    override init() {
        super.init()
        peerID = MCPeerID(displayName: UIDevice.current.name)
    }

    func start() {
        // Check if device supports Nearby Interaction
        guard NISession.isSupported else {
            print("Nearby Interaction not supported on this device")
            return
        }

        // Start NI session
        niSession = NISession()
        niSession?.delegate = self

        // Start Multipeer for discovery token exchange
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self

        // Advertise and browse simultaneously
        mcAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        mcAdvertiser?.delegate = self
        mcAdvertiser?.startAdvertisingPeer()

        mcBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        mcBrowser?.delegate = self
        mcBrowser?.startBrowsingForPeers()

        print("Proximity manager started")
    }

    func stop() {
        niSession?.invalidate()
        mcAdvertiser?.stopAdvertisingPeer()
        mcBrowser?.stopBrowsingForPeers()
        mcSession?.disconnect()
    }

    private func shareDiscoveryToken(with peer: MCPeerID) {
        guard let token = niSession?.discoveryToken else { return }

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try mcSession?.send(data, toPeers: [peer], with: .reliable)
            print("Sent discovery token to \(peer.displayName)")
        } catch {
            print("Failed to send discovery token: \(error)")
        }
    }

    private func updateNearestDistance() {
        if peers.isEmpty {
            nearestDistance = -1
            peerCount = 0
        } else {
            nearestDistance = peers.values.min() ?? -1
            peerCount = peers.count
        }
    }
}

// MARK: - NISessionDelegate
extension ProximityManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for object in nearbyObjects {
            if let distance = object.distance {
                // Find which peer this token belongs to
                for (peerID, token) in peerTokens {
                    // Note: In production, you'd need to match tokens properly
                    // This is simplified for the prototype
                    peers[peerID.displayName] = distance
                }
            }
        }

        DispatchQueue.main.async {
            self.updateNearestDistance()
        }
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Handle peer removal
        DispatchQueue.main.async {
            self.updateNearestDistance()
        }
    }

    func sessionWasSuspended(_ session: NISession) {
        print("NI Session suspended")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        print("NI Session resumed")
        // Re-run configurations for all known peers
        for (_, token) in peerTokens {
            let config = NINearbyPeerConfiguration(peerToken: token)
            session.run(config)
        }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("NI Session invalidated: \(error)")
    }
}

// MARK: - MCSessionDelegate
extension ProximityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected to \(peerID.displayName)")
            shareDiscoveryToken(with: peerID)
        case .notConnected:
            print("Disconnected from \(peerID.displayName)")
            DispatchQueue.main.async {
                self.peers.removeValue(forKey: peerID.displayName)
                self.peerTokens.removeValue(forKey: peerID)
                self.updateNearestDistance()
            }
        case .connecting:
            print("Connecting to \(peerID.displayName)")
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Received discovery token from peer
        do {
            if let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                peerTokens[peerID] = token

                // Configure NI session with this peer's token
                let config = NINearbyPeerConfiguration(peerToken: token)
                niSession?.run(config)

                print("Configured NI with \(peerID.displayName)")
            }
        } catch {
            print("Failed to decode discovery token: \(error)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension ProximityManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations
        invitationHandler(true, mcSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension ProximityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found peer: \(peerID.displayName)")
        // Invite peer to session
        browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
    }
}

#Preview {
    ContentView()
}
