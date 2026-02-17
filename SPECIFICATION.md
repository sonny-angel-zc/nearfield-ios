# Nearfield - UWB iOS App Specification

A native iOS app that uses Ultra-Wideband (UWB) for precise proximity detection in a multi-person sound installation. When people get closer together, their phones' sounds become harmonically richer through wave interference (beating).

## Core Concept

Each phone plays a single tone. When phones are far apart, you hear pure sine waves. As phones approach each other:
1. **Physical beating** occurs naturally in the air (no sync needed)
2. **Harmonic enrichment** is unlocked by proximity - octave, fifth, third fade in

## Requirements

- **Hardware**: iPhone 11 or newer (requires U1 chip for UWB)
- **iOS**: 16.0+
- **Frameworks**: NearbyInteraction, MultipeerConnectivity, WebKit

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI App                             │
│  NearfieldApp.swift                                          │
│  └── WindowGroup → ContentView                               │
├─────────────────────────────────────────────────────────────┤
│                      ContentView                             │
│  ├── ProximityManager (ObservableObject)                    │
│  └── WebViewContainer (UIViewRepresentable)                 │
├─────────────────────────────────────────────────────────────┤
│                   ProximityManager                           │
│  ├── NISession - UWB ranging (centimeter accuracy)          │
│  ├── MCSession - Peer-to-peer connection                    │
│  ├── MCNearbyServiceAdvertiser - Advertise presence         │
│  ├── MCNearbyServiceBrowser - Discover other devices        │
│  └── Published properties:                                   │
│      ├── nearestDistance: Float (-1 if no peer)             │
│      ├── peerCount: Int                                      │
│      └── peers: [String: Float] (name → distance)           │
├─────────────────────────────────────────────────────────────┤
│                      WebViewContainer                        │
│  └── WKWebView                                               │
│      ├── Loads bundled nearfield.html                       │
│      └── JS Bridge: updateNativeProximity(distance, count)  │
├─────────────────────────────────────────────────────────────┤
│                    Web Audio Layer                           │
│  ├── Base oscillator (user's chosen note)                   │
│  ├── Harmonic oscillators (proximity-unlocked)              │
│  │   ├── Octave (2x frequency)                              │
│  │   ├── Fifth (1.5x frequency)                             │
│  │   └── Major Third (1.25x frequency)                      │
│  └── Visual proximity display with rings                    │
└─────────────────────────────────────────────────────────────┘
```

## Connection Flow

```
Device A                              Device B
   │                                      │
   ├── Start MCAdvertiser ───────────────►│
   ├── Start MCBrowser ◄─────────────────┤
   │                                      │
   │◄── foundPeer notification ──────────┤
   │                                      │
   ├── invitePeer() ─────────────────────►│
   │                                      │
   │◄── invitationHandler(true) ─────────┤
   │                                      │
   ├── MCSession connected ◄─────────────►│ MCSession connected
   │                                      │
   ├── shareDiscoveryToken() ────────────►│
   │◄── shareDiscoveryToken() ───────────┤
   │                                      │
   ├── Configure NINearbyPeerConfiguration│
   │◄── Configure NINearbyPeerConfiguration
   │                                      │
   │◄── NISession.didUpdate(distance) ───►│
   │                                      │
   └── Push to WebView ──────────────────►│ Push to WebView
```

## Key Classes

### ProximityManager

```swift
class ProximityManager: NSObject, ObservableObject {
    // Published state (triggers SwiftUI updates)
    @Published var nearestDistance: Float = -1  // -1 = no peer
    @Published var peerCount: Int = 0
    @Published var peers: [String: Float] = [:]  // displayName → distance

    // Nearby Interaction
    private var niSession: NISession?

    // Multipeer Connectivity
    private var mcSession: MCSession?
    private var mcAdvertiser: MCNearbyServiceAdvertiser?
    private var mcBrowser: MCNearbyServiceBrowser?
    private var peerID: MCPeerID!

    // Service type for Bonjour discovery
    private let serviceType = "nearfield"

    // Map peer IDs to their NI tokens
    private var peerTokens: [MCPeerID: NIDiscoveryToken] = [:]
}
```

**Delegate Conformances:**
- `NISessionDelegate` - Receive UWB distance updates
- `MCSessionDelegate` - Handle peer connections and token exchange
- `MCNearbyServiceAdvertiserDelegate` - Accept incoming invitations
- `MCNearbyServiceBrowserDelegate` - Discover and invite peers

### WebViewContainer

```swift
struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var proximityManager: ProximityManager

    func makeUIView(context: Context) -> WKWebView {
        // Configure for inline media playback
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Load bundled HTML
        let webView = WKWebView(frame: .zero, configuration: config)
        if let htmlPath = Bundle.main.path(forResource: "nearfield", ofType: "html") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Push proximity data whenever @Published properties change
        let js = "updateNativeProximity(\(proximityManager.nearestDistance), \(proximityManager.peerCount));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
```

## Token Exchange

The critical step: devices must exchange NIDiscoveryTokens via Multipeer before UWB ranging works.

```swift
private func shareDiscoveryToken(with peer: MCPeerID) {
    guard let token = niSession?.discoveryToken else { return }

    // Serialize token
    let data = try NSKeyedArchiver.archivedData(
        withRootObject: token,
        requiringSecureCoding: true
    )

    // Send via Multipeer
    try mcSession?.send(data, toPeers: [peer], with: .reliable)
}

// On receiving token from peer:
func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    if let token = try NSKeyedUnarchiver.unarchivedObject(
        ofClass: NIDiscoveryToken.self,
        from: data
    ) {
        peerTokens[peerID] = token

        // Configure NI session with peer's token - this starts UWB ranging
        let config = NINearbyPeerConfiguration(peerToken: token)
        niSession?.run(config)
    }
}
```

## JavaScript Bridge Interface

The HTML must implement this function to receive proximity data:

```javascript
// Called by native Swift code via evaluateJavaScript()
function updateNativeProximity(distance, peerCount) {
    // distance: Float in meters, -1 if no peers detected
    // peerCount: Int, number of nearby devices

    proximityDistance = distance;
    proximityPeerCount = peerCount;

    updateProximityUI();   // Update visual display
    updateHarmonics();     // Adjust harmonic gains based on distance
}
```

## Multi-Peer Harmony

Each peer is deterministically assigned a base note from a pentatonic scale based on a hash of their device name. This means:
- The same device always gets the same note
- Multiple nearby peers naturally form pentatonic chords
- No coordination or synchronization needed between devices

Pentatonic scale: C4, D4, E4, G4, A4, C5, D5, E5

## Sound Design

Each peer's audio chain:
```
Sine Osc ──┐
            ├──► Peer Gain ──► StereoPanner ──► Master Gain ──┬──► Destination
Triangle Osc┘                                                  └──► Delay ──► Feedback ──► Delay
                                                                         └──► Wet Gain ──► Destination
```

- **Layered oscillators**: Sine + soft triangle (15% blend) for warmth
- **Delay reverb**: 300ms delay with 25% feedback, 15% wet mix
- **Spatial panning**: `StereoPannerNode` driven by UWB `horizontalAngle` or `directionX`
- **Exponential gain**: `Math.pow(normalized, 2.5)` for natural proximity fade-in

## Proximity → Sound Mapping

Per-peer distance thresholds (exponential gain curves):

| Distance     | Effect                          | Gain Curve           |
|--------------|--------------------------------|----------------------|
| > 3m         | Silent                         | 0                    |
| 1.5-3m       | Peer base note fades in        | exponential ramp     |
| 1-1.5m       | + Octave (2x) emerges          | exponential ramp     |
| 0.5-1m       | + Fifth (1.5x)                 | exponential ramp     |
| < 0.5m       | + Major Third (1.25x)          | full chord           |

## 3D Visualization

- Connecting lines between center sphere and each peer sphere
- Line opacity follows exponential proximity curve (brighter when closer)
- Color shifts from blue (#4a9eff) to warm white (#ffddff) at close range
- Provides visual feedback of harmonic connections between participants

## Required Info.plist Entries

```xml
<!-- Nearby Interaction permissions -->
<key>NSNearbyInteractionAllowOnceUsageDescription</key>
<string>This app uses Nearby Interaction to detect the distance to other phones for the sound installation.</string>
<key>NSNearbyInteractionUsageDescription</key>
<string>This app uses Nearby Interaction to detect the distance to other phones for the sound installation.</string>

<!-- Multipeer Connectivity (Bonjour) -->
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses local network to find other Nearfield devices nearby.</string>
<key>NSBonjourServices</key>
<array>
    <string>_nearfield._tcp</string>
    <string>_nearfield._udp</string>
</array>

<!-- Bluetooth fallback -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is used to discover nearby devices for the sound installation.</string>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>nearby-interaction</string>
</array>
```

## File Structure

```
ios-app/
├── README.md                    # Setup instructions
├── SPECIFICATION.md             # This file
└── Nearfield/
    └── Nearfield/
        ├── NearfieldApp.swift        # @main App entry point
        ├── ContentView.swift          # Main view + ProximityManager
        ├── nearfield.html             # Bundled web audio interface
        └── Info.plist                 # Permissions and config
```

## Build Requirements

1. **Xcode 15+** (required for iOS 16+ deployment)
2. **Apple Developer Account** (required for device testing - UWB doesn't work in simulator)
3. **Two iPhones 11+** for testing peer interaction

## Xcode Project Setup

1. Create new iOS App project (SwiftUI, Swift)
2. Copy source files into project
3. Add frameworks to target:
   - NearbyInteraction.framework
   - MultipeerConnectivity.framework
   - WebKit.framework
4. Set iOS Deployment Target: 16.0
5. Add nearfield.html to bundle (Copy items if needed)
6. Sign with developer account
7. Build and run on physical device

## Limitations

- **Device requirement**: Only iPhone 11+ with U1 chip
- **Pairing**: Both devices must have app installed and running
- **Range**: UWB effective to ~9m, most accurate under 1m
- **Background**: Limited to ~30 seconds of active ranging
- **Simulator**: UWB not available - must test on physical devices

## Testing Checklist

1. [ ] Install on two iPhone 11+ devices
2. [ ] Launch app on both
3. [ ] Both devices show "No devices nearby" initially
4. [ ] After ~5 seconds, devices discover each other
5. [ ] Distance display updates in real-time
6. [ ] Tap Play on both devices
7. [ ] Move devices closer → harmonics fade in
8. [ ] Move devices apart → harmonics fade out
9. [ ] Distance accuracy is within ~10cm
