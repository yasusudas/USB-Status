import Foundation

struct USBProperty: Identifiable, Hashable, Codable, Sendable {
    var id: String { key }
    let key: String
    let value: String
}

enum USBNodeKind: String, Codable, Hashable, Sendable {
    case controller
    case hub
    case storage
    case display
    case mobile
    case input
    case audio
    case network
    case power
    case device
}

struct USBNode: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let vendor: String?
    let productID: String?
    let vendorID: String?
    let serial: String?
    let locationID: String?
    let usbVersion: String?
    let speed: String?
    let currentRequiredMA: Double?
    let currentAvailableMA: Double?
    let extraOperatingCurrentMA: Double?
    let busPowerMA: Double?
    let powerWattsOverride: Double?
    let level: Int
    let kind: USBNodeKind
    let properties: [USBProperty]
    let children: [USBNode]

    var isController: Bool { kind == .controller }
    var isHub: Bool { kind == .hub }
    var portLabel: String {
        guard let locationID, !locationID.isEmpty else { return "P\(max(level, 1))" }
        let digits = locationID.filter(\.isNumber)
        if let last = digits.last {
            return "P\(last)"
        }
        return "P\(max(level, 1))"
    }

    var subtitle: String {
        localizedSubtitle(language: .english)
    }

    func localizedName(language: AppLanguage) -> String {
        L10n.localizedDeviceName(name, language: language)
    }

    func localizedSubtitle(language: AppLanguage) -> String {
        var parts: [String] = []
        if let vendor, !vendor.isEmpty {
            parts.append(vendor)
        }
        if let usbVersion, !usbVersion.isEmpty {
            parts.append(usbVersion)
        }
        if parts.isEmpty {
            return kind.localizedLabel(language: language)
        }
        return parts.joined(separator: " · ")
    }

    var identifierSummary: String {
        localizedIdentifierSummary(language: .english)
    }

    func localizedIdentifierSummary(language: AppLanguage) -> String {
        if let serial, !serial.isEmpty {
            return "SN \(serial)"
        }
        if let locationID, !locationID.isEmpty {
            return "LOC \(locationID)"
        }
        if let vendorID, let productID {
            return "VID/PID \(vendorID):\(productID)"
        }
        return L10n.text(.noHardwareIdentifier, language)
    }

    var powerWatts: Double? {
        if let powerWattsOverride {
            return powerWattsOverride
        }
        guard let currentRequiredMA else { return nil }
        return currentRequiredMA * 5.0 / 1000.0
    }

    func flattened() -> [USBNode] {
        [self] + children.flatMap { $0.flattened() }
    }
}

extension USBNodeKind {
    var label: String {
        localizedLabel(language: .english)
    }

    func localizedLabel(language: AppLanguage) -> String {
        switch self {
        case .controller: L10n.text(.kindController, language)
        case .hub: L10n.text(.kindHub, language)
        case .storage: L10n.text(.kindStorage, language)
        case .display: L10n.text(.kindDisplay, language)
        case .mobile: L10n.text(.kindMobile, language)
        case .input: L10n.text(.kindInput, language)
        case .audio: L10n.text(.kindAudio, language)
        case .network: L10n.text(.kindNetwork, language)
        case .power: L10n.text(.kindPower, language)
        case .device: L10n.text(.kindDevice, language)
        }
    }

    var symbolName: String {
        switch self {
        case .controller: "server.rack"
        case .hub: "square.stack.3d.up"
        case .storage: "externaldrive"
        case .display: "display"
        case .mobile: "ipad"
        case .input: "keyboard"
        case .audio: "speaker.wave.2"
        case .network: "network"
        case .power: "powerplug"
        case .device: "cable.connector"
        }
    }
}

struct ThunderboltPort: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let busName: String
    let deviceName: String
    let vendorName: String?
    let portNumber: String
    let speed: String?
    let status: String
    let route: String?
    let properties: [USBProperty]
}

struct USBTypeCPort: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let portNumber: String
    let isConnected: Bool
    let deviceName: String
    let detail: String?
    let transports: String?
    let dataRate: String?
    let powerWatts: Double?
    let voltageMV: Double?
    let currentMA: Double?
    let serial: String?
    let properties: [USBProperty]
}

struct ConnectionEvent: Identifiable, Hashable, Codable, Sendable {
    enum EventKind: String, Codable, Sendable {
        case connected
        case disconnected
    }

    let id: UUID
    let date: Date
    let deviceName: String
    let kind: EventKind
}

struct USBVolume: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let deviceIdentifier: String
    let parentDiskIdentifier: String?
    let parentDiskMediaName: String?
    let mountPoint: String?
    let fileSystem: String?
    let sizeBytes: Int64?
    let freeBytes: Int64?
    let encrypted: Bool?
    let readOnly: Bool?
    let writable: Bool?
    let busProtocol: String?
    let deviceTreePath: String?

    var isMounted: Bool {
        guard let mountPoint else { return false }
        return !mountPoint.isEmpty
    }

    var usedBytes: Int64? {
        guard let sizeBytes, let freeBytes else { return nil }
        return max(0, sizeBytes - freeBytes)
    }

    var usedFraction: Double {
        guard let sizeBytes, let usedBytes, sizeBytes > 0 else { return 0 }
        return min(1, max(0, Double(usedBytes) / Double(sizeBytes)))
    }
}

struct USBSnapshot: Hashable, Codable, Sendable {
    let hostName: String
    let usbRoots: [USBNode]
    let thunderboltPorts: [ThunderboltPort]
    let typeCPorts: [USBTypeCPort]
    let externalVolumes: [USBVolume]
    let capturedAt: Date
    let rawJSONString: String

    static var empty: USBSnapshot {
        USBSnapshot(
            hostName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            usbRoots: [],
            thunderboltPorts: [],
            typeCPorts: [],
            externalVolumes: [],
            capturedAt: Date(),
            rawJSONString: "{}"
        )
    }

    var allUSBNodes: [USBNode] {
        usbRoots.flatMap { $0.flattened() }
    }

    var connectedDevices: [USBNode] {
        allUSBNodes.filter { !$0.isController }
    }

    var controllers: [USBNode] {
        allUSBNodes.filter(\.isController)
    }

    var hubs: [USBNode] {
        connectedDevices.filter(\.isHub)
    }

    var deviceCount: Int {
        connectedDevices.filter { !$0.isHub }.count
    }

    var hubCount: Int {
        hubs.count
    }

    var estimatedWatts: Double {
        connectedDevices.compactMap(\.powerWatts).reduce(0, +)
    }
}
