import SwiftUI
import WebKit
import NearbyInteraction
import MultipeerConnectivity
import CoreMotion
import CoreBluetooth
import UIKit
import AVFoundation

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var proximityManager = ProximityManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            backgroundGradient

            if hasSeenOnboarding {
                WebViewContainer(proximityManager: proximityManager)
                    .ignoresSafeArea(edges: [.top, .horizontal])
                    .transition(.opacity)

                // Grainfield mode toggle
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proximityManager.toggleGrainfieldMode()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(proximityManager.isGrainfieldActive
                                          ? Color(red: 0.4, green: 0.85, blue: 0.55)
                                          : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Text(proximityManager.grainfieldStatusLabel)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                                    .overlay(
                                        Capsule()
                                            .stroke(proximityManager.isGrainfieldActive
                                                    ? Color(red: 0.4, green: 0.85, blue: 0.55).opacity(0.4)
                                                    : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                    }
                    Spacer()
                }
            }

            if hasSeenOnboarding, let reconnectBanner = proximityManager.transientStatusText {
                VStack {
                    Text(reconnectBanner)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.top, 22)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !hasSeenOnboarding {
                OnboardingView(proximityManager: proximityManager) {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .onAppear {
            if hasSeenOnboarding {
                proximityManager.startExperience()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                proximityManager.handleAppBackground()
            case .active:
                proximityManager.handleAppForeground()
            default:
                break
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.04, blue: 0.08),
                Color(red: 0.08, green: 0.09, blue: 0.16),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct OnboardingView: View {
    @ObservedObject var proximityManager: ProximityManager
    let onComplete: () -> Void

    @State private var stage: Stage = .concept
    @State private var isBusy = false
    @State private var pulse = false
    @State private var finishTask: Task<Void, Never>?
    @State private var displayName: String = ProximityManager.storedDisplayName()
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.08),
                    Color(red: 0.08, green: 0.09, blue: 0.18),
                    Color(red: 0.11, green: 0.05, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 220, height: 220)
                        .blur(radius: 4)

                    if stage == .searching {
                        PulseRings(isAnimating: pulse)
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.56, green: 0.74, blue: 1.0), Color(red: 0.26, green: 0.52, blue: 0.98)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 104, height: 104)
                        .shadow(color: Color(red: 0.42, green: 0.61, blue: 1.0).opacity(0.4), radius: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                }
                .frame(height: 240)

                VStack(spacing: 12) {
                    Text(stage.eyebrow)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .textCase(.uppercase)
                        .tracking(1.6)

                    Text(stage.title)
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(stage.message(peerCount: proximityManager.peerCount))
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                if stage == .concept {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Display name")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .textCase(.uppercase)
                            .tracking(1.3)

                        TextField("Choose a name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .focused($isNameFocused)
                            .submitLabel(.continue)
                            .onSubmit(handlePrimaryAction)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 28)
                }

                if stage != .searching {
                    Button(action: handlePrimaryAction) {
                        HStack(spacing: 10) {
                            if isBusy {
                                ProgressView()
                                    .tint(.black.opacity(0.8))
                            }

                            Text(stage.buttonTitle)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color.black.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(red: 0.94, green: 0.91, blue: 0.84))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy || (stage == .concept && trimmedDisplayName.isEmpty))
                    .padding(.horizontal, 28)
                } else {
                    VStack(spacing: 10) {
                        Text("Searching for peers")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))

                        Text(searchingFootnote)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }

                Spacer()
            }
            .padding(.vertical, 24)
        }
        .onChange(of: stage) { newStage in
            guard newStage == .searching else { return }
            pulse = true
            proximityManager.startExperience()

            finishTask?.cancel()
            finishTask = Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    onComplete()
                }
            }
        }
        .onDisappear {
            finishTask?.cancel()
        }
        .onAppear {
            if stage == .concept && displayName == ProximityManager.storedDisplayName() {
                isNameFocused = displayName.isEmpty
            }
        }
    }

    private var searchingFootnote: String {
        if proximityManager.peerCount > 0 {
            return "\(proximityManager.peerCount) device\(proximityManager.peerCount == 1 ? "" : "s") nearby"
        }
        return "Bring another phone close to start weaving harmonics."
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handlePrimaryAction() {
        guard !isBusy else { return }

        switch stage {
        case .concept:
            guard !trimmedDisplayName.isEmpty else { return }
            proximityManager.saveLocalDisplayName(trimmedDisplayName)
            isNameFocused = false
            advance()
        case .nearbyInteraction:
            runStep {
                proximityManager.prepareNearbyInteraction()
            }
        case .localNetwork:
            runStep {
                proximityManager.prepareLocalConnectivity()
            }
        case .bluetooth:
            runStep {
                proximityManager.prepareBluetoothPermission()
            }
        case .searching:
            break
        }
    }

    private func runStep(_ action: @escaping () -> Void) {
        isBusy = true
        action()

        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            await MainActor.run {
                isBusy = false
                advance()
            }
        }
    }

    private func advance() {
        guard let nextIndex = Stage.allCases.firstIndex(of: stage).map({ $0 + 1 }),
              nextIndex < Stage.allCases.count else {
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            stage = Stage.allCases[nextIndex]
        }
    }

    private enum Stage: CaseIterable {
        case concept
        case nearbyInteraction
        case localNetwork
        case bluetooth
        case searching

        var eyebrow: String {
            switch self {
            case .concept: return "Nearfield"
            case .nearbyInteraction: return "Permission 1 of 3"
            case .localNetwork: return "Permission 2 of 3"
            case .bluetooth: return "Permission 3 of 3"
            case .searching: return "Ready"
            }
        }

        var title: String {
            switch self {
            case .concept: return "Phones become one instrument."
            case .nearbyInteraction: return "Allow precise distance."
            case .localNetwork: return "Allow nearby discovery."
            case .bluetooth: return "Allow short-range handoff."
            case .searching: return "Listening for the room."
            }
        }

        var buttonTitle: String {
            switch self {
            case .concept: return "Begin"
            case .nearbyInteraction: return "Allow UWB"
            case .localNetwork: return "Allow Local Network"
            case .bluetooth: return "Allow Bluetooth"
            case .searching: return ""
            }
        }

        func message(peerCount: Int) -> String {
            switch self {
            case .concept:
                return "Each phone holds a tone. Bring devices together and new harmonics bloom between them."
            case .nearbyInteraction:
                return "Nearfield uses Ultra Wideband to measure distance in real time, so sound can open up as bodies move closer."
            case .localNetwork:
                return "Nearby devices need a quiet local channel to find each other and exchange ranging tokens."
            case .bluetooth:
                return "Bluetooth helps the installation discover peers smoothly when people drift in and out of range."
            case .searching:
                return peerCount > 0
                    ? "A nearby voice is already in range. Start playing and move closer."
                    : "Permissions are set. Hold another Nearfield phone nearby and the field will begin to sing."
            }
        }
    }
}

private struct PulseRings: View {
    let isAnimating: Bool

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .frame(width: 110, height: 110)
                    .scaleEffect(isAnimating ? 1.5 + CGFloat(index) * 0.36 : 0.78)
                    .opacity(isAnimating ? 0.0 : 0.28)
                    .animation(
                        .easeOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.45),
                        value: isAnimating
                    )
            }
        }
    }
}

// MARK: - Peer Data with Direction
struct PeerData: Codable {
    var distance: Float
    var directionX: Float
    var directionY: Float
    var directionZ: Float
    var horizontalAngle: Float
}

struct PeerDebugData: Codable {
    var distance: Float
    var packetLoss: Float
}

struct DebugSnapshot: Codable {
    var uwbState: String
    var connectivityState: String
    var grainfieldMode: String
    var grainfieldBufferAge: Float
    var grainfieldRate: Float
    var peers: [String: PeerDebugData]

    static let empty = DebugSnapshot(
        uwbState: "idle",
        connectivityState: "idle",
        grainfieldMode: "Nearfield fallback",
        grainfieldBufferAge: -1,
        grainfieldRate: 0,
        peers: [:]
    )
}

private struct AudioBufferPayload: Codable {
    var pcmData: Data
    var sampleRate: Double
    var channelCount: Int
    var bufferDuration: Double
    var sentAt: Double
}

private struct SessionPayload: Codable {
    var kind: String
    var displayName: String?
    var tokenData: Data?
    var audioBuffer: AudioBufferPayload?
}

private struct GrainfieldBridgePayload: Codable {
    var base64: String
    var sampleRate: Double
    var channelCount: Int
    var bufferDuration: Double
    var sentAt: Double
}

// MARK: - WebView Container
struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var proximityManager: ProximityManager

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        config.userContentController.add(context.coordinator, name: "nativeHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        if let htmlPath = Bundle.main.path(forResource: "nearfield", ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        context.coordinator.webView = webView
        proximityManager.attachWebView(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let peersJSON: String
        if let jsonData = try? JSONEncoder().encode(proximityManager.peersData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            peersJSON = jsonString
        } else {
            peersJSON = "{}"
        }

        let debugJSON: String
        if let jsonData = try? JSONEncoder().encode(proximityManager.debugSnapshot),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            debugJSON = jsonString
        } else {
            debugJSON = "{}"
        }

        let js = """
        updateNativeData({
            nearestDistance: \(proximityManager.nearestDistance),
            peerCount: \(proximityManager.peerCount),
            peers: \(peersJSON),
            debug: \(debugJSON),
            tiltX: \(proximityManager.tiltX),
            tiltY: \(proximityManager.tiltY),
            grainfieldEnabled: \(proximityManager.isGrainfieldActive ? "true" : "false"),
            grainfieldRole: "\(proximityManager.grainfieldRoleIdentifier)",
            grainfieldBufferAge: \(proximityManager.grainfieldBufferAge),
            grainRate: \(proximityManager.grainRate)
        });
        """
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
            if let body = message.body as? [String: Any] {
                print("Message from web: \(body)")
            }
        }
    }
}

// MARK: - Proximity Manager with Direction + Tilt
class ProximityManager: NSObject, ObservableObject {
    static let displayNameDefaultsKey = "nearfieldDisplayName"

    @Published var nearestDistance: Float = -1
    @Published var peerCount: Int = 0
    @Published var peersData: [String: PeerData] = [:]
    @Published var tiltX: Float = 0
    @Published var tiltY: Float = 0
    @Published var debugSnapshot: DebugSnapshot = .empty
    @Published var transientStatusText: String?
    @Published var isGrainfieldEnabled: Bool = false
    @Published var isGrainfieldListening: Bool = false

    private var niSession: NISession?
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    private var mcBrowser: MCNearbyServiceBrowser?
    private var bluetoothManager: CBCentralManager?
    private var peerID: MCPeerID!
    private var localDisplayName: String

    private let serviceType = "nearfield"
    private var peerTokens: [MCPeerID: NIDiscoveryToken] = [:]
    private var peerDisplayNames: [MCPeerID: String] = [:]
    private var peerSuccessCounts: [MCPeerID: Int] = [:]
    private var peerMissCounts: [MCPeerID: Int] = [:]
    private let motionManager = CMMotionManager()
    private let discoveryFeedback = UIImpactFeedbackGenerator(style: .light)
    private let proximityFeedback = UIImpactFeedbackGenerator(style: .soft)
    private let disconnectFeedback = UINotificationFeedbackGenerator()
    private let audioEngine = AVAudioEngine()
    private var audioConverter: AVAudioConverter?
    private let grainfieldBus = DispatchQueue(label: "nearfield.grainfield.audio")
    private weak var webView: WKWebView?

    private var didStartMotion = false
    private var didStartConnectivity = false
    private var didStartExperience = false
    private var lastProximityPulseDate = Date.distantPast
    private var needsReconnect = false
    private var grainfieldChunkDuration: TimeInterval = 2.0
    private let grainfieldSampleRate: Double = 44_100
    private var grainfieldAccumulatedSamples: [Float] = []
    private var lastGrainfieldBufferDate: Date?

    var isGrainfieldPrimary: Bool {
        isGrainfieldEnabled
    }

    var isGrainfieldActive: Bool {
        isGrainfieldEnabled || isGrainfieldListening
    }

    var grainfieldRoleIdentifier: String {
        if isGrainfieldPrimary { return "primary" }
        if isGrainfieldListening { return "listening" }
        return "inactive"
    }

    var grainfieldStatusLabel: String {
        if isGrainfieldPrimary { return "Grainfield (Primary)" }
        if isGrainfieldListening { return "Grainfield (Listening)" }
        return "Nearfield"
    }

    var grainfieldBufferAge: Float {
        guard let lastGrainfieldBufferDate else { return -1 }
        return Float(Date().timeIntervalSince(lastGrainfieldBufferDate))
    }

    var grainRate: Float {
        guard isGrainfieldActive else { return 0 }
        let peerFactor = max(Float(peerCount), 1)
        let distance = nearestDistance > 0 ? nearestDistance : 1.6
        let proximity = max(0, min(1, 1 - (distance / 3.0)))
        return 8 + (peerFactor * 3) + (proximity * 12)
    }

    override init() {
        localDisplayName = Self.storedDisplayName()
        super.init()
        peerID = MCPeerID(displayName: UIDevice.current.name)
    }

    static func storedDisplayName() -> String {
        let savedName = UserDefaults.standard.string(forKey: displayNameDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let savedName, !savedName.isEmpty {
            return savedName
        }
        return UIDevice.current.name
    }

    func saveLocalDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        localDisplayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.displayNameDefaultsKey)
    }

    func attachWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    func toggleGrainfieldMode() {
        setGrainfieldEnabled(!isGrainfieldEnabled)
    }

    func setGrainfieldEnabled(_ enabled: Bool) {
        guard enabled != isGrainfieldEnabled else { return }
        isGrainfieldEnabled = enabled
        if enabled {
            isGrainfieldListening = false
            requestMicrophoneAccessAndStartCapture()
        } else {
            stopGrainfieldCapture()
        }
        updateDebugSnapshot()
    }

    private func prepareHaptics() {
        discoveryFeedback.prepare()
        proximityFeedback.prepare()
        disconnectFeedback.prepare()
    }

    func prepareNearbyInteraction() {
        guard NISession.isSupported else {
            print("Nearby Interaction not supported on this device")
            return
        }

        guard niSession == nil else { return }
        niSession = NISession()
        niSession?.delegate = self
        _ = niSession?.discoveryToken
        debugSnapshot.uwbState = "ready"
        updateDebugSnapshot()
    }

    func prepareLocalConnectivity() {
        if mcSession == nil {
            let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
            session.delegate = self
            mcSession = session
        }

        guard !didStartConnectivity else { return }

        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        mcAdvertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        mcBrowser = browser

        didStartConnectivity = true
        print("Connectivity started")
        updateDebugSnapshot()
    }

    func prepareBluetoothPermission() {
        guard bluetoothManager == nil else { return }
        bluetoothManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
    }

    func startExperience() {
        guard !didStartExperience else { return }
        didStartExperience = true

        prepareHaptics()
        prepareNearbyInteraction()
        prepareLocalConnectivity()
        prepareBluetoothPermission()
        startMotionUpdates()

        print("Proximity manager started")
        updateDebugSnapshot()
    }

    private func startMotionUpdates() {
        guard !didStartMotion else { return }
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        didStartMotion = true
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion, let self else { return }
            self.tiltX = Float(motion.attitude.roll)
            self.tiltY = Float(motion.attitude.pitch)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        stopGrainfieldCapture()
        niSession?.invalidate()
        mcAdvertiser?.stopAdvertisingPeer()
        mcBrowser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        bluetoothManager = nil
        didStartMotion = false
        didStartConnectivity = false
        didStartExperience = false
        needsReconnect = false
        debugSnapshot = .empty
    }

    private func shareDiscoveryToken(with peer: MCPeerID) {
        guard let token = niSession?.discoveryToken else { return }

        do {
            let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            let payload = SessionPayload(kind: "token", displayName: nil, tokenData: tokenData, audioBuffer: nil)
            let data = try JSONEncoder().encode(payload)
            try mcSession?.send(data, toPeers: [peer], with: .reliable)
            print("Sent discovery token to \(peer.displayName)")
        } catch {
            print("Failed to send discovery token: \(error)")
        }
    }

    private func shareSessionMetadata(with peer: MCPeerID) {
        do {
            let payload = SessionPayload(kind: "metadata", displayName: localDisplayName, tokenData: nil, audioBuffer: nil)
            let data = try JSONEncoder().encode(payload)
            try mcSession?.send(data, toPeers: [peer], with: .reliable)
            print("Sent display name to \(peer.displayName)")
        } catch {
            print("Failed to send display name: \(error)")
        }
    }

    private func updateNearestDistance() {
        if peersData.isEmpty {
            nearestDistance = -1
            peerCount = 0
        } else {
            nearestDistance = peersData.values.map(\.distance).min() ?? -1
            peerCount = peersData.count
        }

        updateDebugSnapshot()
    }

    private func requestMicrophoneAccessAndStartCapture() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            startGrainfieldCapture()
        case .denied:
            DispatchQueue.main.async {
                self.isGrainfieldEnabled = false
                self.updateDebugSnapshot()
            }
        case .undetermined:
            session.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.startGrainfieldCapture()
                    } else {
                        self.isGrainfieldEnabled = false
                        self.updateDebugSnapshot()
                    }
                }
            }
        @unknown default:
            isGrainfieldEnabled = false
            updateDebugSnapshot()
        }
    }

    private func startGrainfieldCapture() {
        grainfieldBus.async {
            guard !self.audioEngine.isRunning else { return }

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
                try audioSession.setPreferredSampleRate(self.grainfieldSampleRate)
                try audioSession.setPreferredIOBufferDuration(0.023)
                try audioSession.setActive(true, options: [])
            } catch {
                print("Failed to configure AVAudioSession: \(error)")
                DispatchQueue.main.async {
                    self.isGrainfieldEnabled = false
                    self.updateDebugSnapshot()
                }
                return
            }

            let inputNode = self.audioEngine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                   sampleRate: self.grainfieldSampleRate,
                                                   channels: 1,
                                                   interleaved: false) else {
                return
            }

            self.audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
            self.grainfieldAccumulatedSamples.removeAll(keepingCapacity: true)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
                self?.handleCapturedAudioBuffer(buffer)
            }

            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
                DispatchQueue.main.async {
                    self.updateDebugSnapshot()
                }
            } catch {
                print("Failed to start AVAudioEngine: \(error)")
                inputNode.removeTap(onBus: 0)
                DispatchQueue.main.async {
                    self.isGrainfieldEnabled = false
                    self.updateDebugSnapshot()
                }
            }
        }
    }

    private func stopGrainfieldCapture() {
        grainfieldBus.async {
            let inputNode = self.audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            self.audioEngine.stop()
            self.audioConverter = nil
            self.grainfieldAccumulatedSamples.removeAll(keepingCapacity: false)
        }
    }

    private func handleCapturedAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isGrainfieldEnabled,
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: grainfieldSampleRate,
                                               channels: 1,
                                               interleaved: false),
              let convertedBuffer = convertToGrainfieldBuffer(buffer, outputFormat: outputFormat),
              let channelData = convertedBuffer.floatChannelData?.pointee else {
            return
        }

        let frameCount = Int(convertedBuffer.frameLength)
        grainfieldAccumulatedSamples.append(contentsOf: UnsafeBufferPointer(start: channelData, count: frameCount))

        let chunkSize = Int(grainfieldSampleRate * grainfieldChunkDuration)
        guard grainfieldAccumulatedSamples.count >= chunkSize else { return }

        let chunk = Array(grainfieldAccumulatedSamples.prefix(chunkSize))
        grainfieldAccumulatedSamples.removeFirst(chunkSize)
        sendGrainfieldChunk(chunk)
    }

    private func convertToGrainfieldBuffer(_ buffer: AVAudioPCMBuffer, outputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let audioConverter else { return nil }

        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate) + 32
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        var error: NSError?
        var didProvideInput = false
        let status = audioConverter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error else {
            if let error {
                print("Audio conversion failed: \(error)")
            }
            return nil
        }

        return outputBuffer
    }

    private func sendGrainfieldChunk(_ samples: [Float]) {
        let pcmData = samples.withUnsafeBufferPointer { Data(buffer: $0) }
        let payload = AudioBufferPayload(
            pcmData: pcmData,
            sampleRate: grainfieldSampleRate,
            channelCount: 1,
            bufferDuration: grainfieldChunkDuration,
            sentAt: Date().timeIntervalSince1970
        )

        do {
            let sessionPayload = SessionPayload(kind: "audioBuffer", displayName: localDisplayName, tokenData: nil, audioBuffer: payload)
            let encoded = try JSONEncoder().encode(sessionPayload)
            if let mcSession, !mcSession.connectedPeers.isEmpty {
                try mcSession.send(encoded, toPeers: mcSession.connectedPeers, with: .unreliable)
            }
            handleIncomingAudioBuffer(payload, from: peerID)
        } catch {
            print("Failed to send Grainfield buffer: \(error)")
        }
    }

    private func resolvedDisplayName(for peer: MCPeerID) -> String {
        peerDisplayNames[peer] ?? peer.displayName
    }

    private func registerDisplayName(_ displayName: String, for peer: MCPeerID) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        DispatchQueue.main.async {
            let previousName = self.peerDisplayNames[peer] ?? peer.displayName
            self.peerDisplayNames[peer] = trimmed

            if previousName != trimmed, let data = self.peersData.removeValue(forKey: previousName) {
                self.peersData[trimmed] = data
                self.updateNearestDistance()
            }

            self.updateDebugSnapshot()
        }
    }

    private func triggerDiscoveryHaptic() {
        DispatchQueue.main.async {
            self.discoveryFeedback.impactOccurred(intensity: 0.55)
            self.discoveryFeedback.prepare()
        }
    }

    private func triggerDisconnectHaptic() {
        DispatchQueue.main.async {
            self.disconnectFeedback.notificationOccurred(.warning)
            self.disconnectFeedback.prepare()
        }
    }

    private func updateProximityHaptics(with distance: Float) {
        guard distance > 0, distance < 0.3 else { return }

        let now = Date()
        let normalized = max(0, min(1, (0.3 - distance) / 0.3))
        let minimumInterval = 0.55 - (Double(normalized) * 0.32)
        guard now.timeIntervalSince(lastProximityPulseDate) >= minimumInterval else { return }

        lastProximityPulseDate = now

        DispatchQueue.main.async {
            self.proximityFeedback.impactOccurred(intensity: CGFloat(0.25 + normalized * 0.55))
            self.proximityFeedback.prepare()
        }
    }

    private func updateDebugSnapshot() {
        let connectivitySummary: String
        if let mcSession {
            connectivitySummary = "\(mcSession.connectedPeers.count) connected"
        } else if didStartConnectivity {
            connectivitySummary = "searching"
        } else {
            connectivitySummary = "idle"
        }

        let peerDebug = Dictionary(uniqueKeysWithValues: peerTokens.keys.map { peer in
            let success = peerSuccessCounts[peer, default: 0]
            let miss = peerMissCounts[peer, default: 0]
            let total = max(success + miss, 1)
            let packetLoss = Float(miss) / Float(total)
            let name = resolvedDisplayName(for: peer)
            let distance = peersData[name]?.distance ?? -1
            return (name, PeerDebugData(distance: distance, packetLoss: packetLoss))
        })

        debugSnapshot = DebugSnapshot(
            uwbState: debugSnapshot.uwbState,
            connectivityState: connectivitySummary,
            grainfieldMode: isGrainfieldPrimary ? "Grainfield primary" : (isGrainfieldListening ? "Grainfield listening" : "Nearfield fallback"),
            grainfieldBufferAge: grainfieldBufferAge,
            grainfieldRate: grainRate,
            peers: peerDebug
        )
    }

    private func handleIncomingAudioBuffer(_ audioBuffer: AudioBufferPayload, from peer: MCPeerID) {
        DispatchQueue.main.async {
            self.lastGrainfieldBufferDate = Date()
            if !self.isGrainfieldPrimary {
                self.isGrainfieldListening = true
            }
            self.updateDebugSnapshot()
            self.pushAudioBufferToWebView(audioBuffer, from: peer)
        }
    }

    private func pushAudioBufferToWebView(_ audioBuffer: AudioBufferPayload, from peer: MCPeerID) {
        guard let webView else { return }

        let bridgePayload = GrainfieldBridgePayload(
            base64: audioBuffer.pcmData.base64EncodedString(),
            sampleRate: audioBuffer.sampleRate,
            channelCount: audioBuffer.channelCount,
            bufferDuration: audioBuffer.bufferDuration,
            sentAt: audioBuffer.sentAt
        )

        guard let jsonData = try? JSONEncoder().encode(bridgePayload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        let sourceName = resolvedDisplayName(for: peer)
        let js = "window.receiveGrainfieldBuffer(\(jsonString), \(jsonStringLiteral(sourceName)));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func jsonStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
    }

    func handleAppBackground() {
        guard didStartExperience else { return }
        needsReconnect = true
        transientStatusText = nil

        motionManager.stopDeviceMotionUpdates()
        didStartMotion = false

        niSession?.invalidate()
        niSession = nil

        mcAdvertiser?.stopAdvertisingPeer()
        mcAdvertiser = nil

        mcBrowser?.stopBrowsingForPeers()
        mcBrowser = nil

        mcSession?.disconnect()
        mcSession = nil

        didStartConnectivity = false
        debugSnapshot.uwbState = "backgrounded"
        updateDebugSnapshot()
    }

    func handleAppForeground() {
        guard didStartExperience, needsReconnect else { return }

        needsReconnect = false
        peerTokens.removeAll()
        peerSuccessCounts.removeAll()
        peerMissCounts.removeAll()
        peersData.removeAll()
        isGrainfieldListening = false
        lastGrainfieldBufferDate = nil
        updateNearestDistance()

        transientStatusText = "Reconnecting..."
        debugSnapshot.uwbState = "reconnecting"

        prepareNearbyInteraction()
        prepareLocalConnectivity()
        prepareBluetoothPermission()
        startMotionUpdates()
        updateDebugSnapshot()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if self.transientStatusText == "Reconnecting..." {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.transientStatusText = nil
                }
            }
        }
    }
}

// MARK: - NISessionDelegate
extension ProximityManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        debugSnapshot.uwbState = "ranging"
        var seenPeers = Set<MCPeerID>()

        for object in nearbyObjects {
            for (peer, token) in peerTokens {
                if let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true),
                   let objectTokenData = try? NSKeyedArchiver.archivedData(withRootObject: object.discoveryToken, requiringSecureCoding: true),
                   tokenData == objectTokenData {
                    seenPeers.insert(peer)
                    peerSuccessCounts[peer, default: 0] += 1

                    let distance = object.distance ?? -1
                    let direction = object.direction ?? simd_float3(0, 0, 0)

                    var horizontalAngle: Float = 0
                    if #available(iOS 16.0, *) {
                        horizontalAngle = object.horizontalAngle ?? 0
                    }

                    DispatchQueue.main.async {
                        self.peersData[self.resolvedDisplayName(for: peer)] = PeerData(
                            distance: distance,
                            directionX: direction.x,
                            directionY: direction.y,
                            directionZ: direction.z,
                            horizontalAngle: horizontalAngle
                        )
                        self.updateNearestDistance()
                        self.updateProximityHaptics(with: distance)
                    }
                    break
                }
            }
        }

        for peer in peerTokens.keys where !seenPeers.contains(peer) {
            peerMissCounts[peer, default: 0] += 1
        }

        updateDebugSnapshot()
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        for object in nearbyObjects {
            for (peer, token) in peerTokens {
                if let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true),
                   let objectTokenData = try? NSKeyedArchiver.archivedData(withRootObject: object.discoveryToken, requiringSecureCoding: true),
                   tokenData == objectTokenData {
                    DispatchQueue.main.async {
                        self.peersData.removeValue(forKey: self.resolvedDisplayName(for: peer))
                        self.updateNearestDistance()
                    }
                    break
                }
            }
        }
    }

    func sessionWasSuspended(_ session: NISession) {
        print("NI Session suspended")
        debugSnapshot.uwbState = "suspended"
        updateDebugSnapshot()
    }

    func sessionSuspensionEnded(_ session: NISession) {
        print("NI Session resumed")
        debugSnapshot.uwbState = "resumed"
        for token in peerTokens.values {
            let config = NINearbyPeerConfiguration(peerToken: token)
            session.run(config)
        }
        updateDebugSnapshot()
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("NI Session invalidated: \(error)")
        debugSnapshot.uwbState = "invalidated"
        updateDebugSnapshot()
    }
}

// MARK: - MCSessionDelegate
extension ProximityManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected to \(peerID.displayName)")
            shareSessionMetadata(with: peerID)
            shareDiscoveryToken(with: peerID)
            updateDebugSnapshot()
        case .notConnected:
            print("Disconnected from \(peerID.displayName)")
            triggerDisconnectHaptic()
            DispatchQueue.main.async {
                let peerName = self.resolvedDisplayName(for: peerID)
                self.peersData.removeValue(forKey: peerName)
                self.peerTokens.removeValue(forKey: peerID)
                self.peerDisplayNames.removeValue(forKey: peerID)
                self.peerSuccessCounts.removeValue(forKey: peerID)
                self.peerMissCounts.removeValue(forKey: peerID)
                self.updateNearestDistance()
            }
        case .connecting:
            print("Connecting to \(peerID.displayName)")
            updateDebugSnapshot()
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            if let payload = try? JSONDecoder().decode(SessionPayload.self, from: data) {
                switch payload.kind {
                case "metadata":
                    if let displayName = payload.displayName {
                        registerDisplayName(displayName, for: peerID)
                    }
                case "token":
                    if let tokenData = payload.tokenData,
                       let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData) {
                        peerTokens[peerID] = token
                        let config = NINearbyPeerConfiguration(peerToken: token)
                        niSession?.run(config)
                        debugSnapshot.uwbState = "token exchanged"
                        updateDebugSnapshot()
                        print("Configured NI with \(peerID.displayName)")
                    }
                case "audioBuffer":
                    if let audioBuffer = payload.audioBuffer {
                        handleIncomingAudioBuffer(audioBuffer, from: peerID)
                    }
                default:
                    break
                }
                return
            }

            if let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                peerTokens[peerID] = token
                let config = NINearbyPeerConfiguration(peerToken: token)
                niSession?.run(config)
                debugSnapshot.uwbState = "token exchanged"
                updateDebugSnapshot()
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
        invitationHandler(true, mcSession)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension ProximityManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("Found peer: \(peerID.displayName)")
        triggerDiscoveryHaptic()
        guard let mcSession else { return }
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer: \(peerID.displayName)")
    }
}

// MARK: - CBCentralManagerDelegate
extension ProximityManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Bluetooth state: \(central.state.rawValue)")
    }
}

#Preview {
    ContentView()
}
