import AppKit
import Foundation
import CoreGraphics

enum PanelMode: String, CaseIterable, Identifiable {
    case devices = "Devices"
    case ports = "Ports"
    case detail = "Info"

    var id: String { rawValue }

    func localizedTitle(language: AppLanguage) -> String {
        switch self {
        case .devices:
            L10n.text(.devices, language)
        case .ports:
            L10n.text(.ports, language)
        case .detail:
            L10n.text(.info, language)
        }
    }
}

@MainActor
final class USBStatusStore: ObservableObject {
    @Published private(set) var snapshot: USBSnapshot = .empty
    @Published private(set) var events: [ConnectionEvent] = []
    @Published var selectedDeviceID: USBNode.ID?
    @Published var selectedDeviceRowCenter: CGFloat?
    @Published var mode: PanelMode = .devices
    @Published private(set) var isLoading = false
    @Published private(set) var unmountingVolumeIDs: Set<USBVolume.ID> = []
    @Published private(set) var errorMessage: String?

    private let profiler = USBProfiler()
    private var refreshTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var needsRefreshAfterCurrentLoad = false
    private var knownDeviceIDs: Set<USBNode.ID> = []
    private let eventsKey = "USBStatus.connectionEvents"

    init() {
        events = loadPersistedEvents()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        registerWorkspaceVolumeNotifications()
        Task { await refresh() }
    }

    var filteredDevices: [USBNode] {
        snapshot.connectedDevices
    }

    var selectedDevice: USBNode? {
        guard let selectedDeviceID else { return nil }
        return snapshot.allUSBNodes.first { $0.id == selectedDeviceID }
    }

    func displayName(for device: USBNode) -> String {
        if device.kind == .storage, let volume = primaryVolume(for: device) {
            return volume.name
        }
        return device.name
    }

    func volumes(for device: USBNode) -> [USBVolume] {
        guard device.kind == .storage else { return [] }
        let volumes = snapshot.externalVolumes.filter { !unmountingVolumeIDs.contains($0.id) }
        if volumes.isEmpty { return [] }

        return USBVolumeMatcher.matchedVolumes(
            for: device,
            in: volumes,
            allStorageDevices: snapshot.connectedDevices.filter { $0.kind == .storage }
        )
    }

    func primaryVolume(for device: USBNode) -> USBVolume? {
        volumes(for: device).first
    }

    func refresh(force: Bool = false) async {
        if isLoading {
            if force {
                needsRefreshAfterCurrentLoad = true
            }
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            let newSnapshot = try await profiler.loadSnapshot()
            captureConnectionChanges(newSnapshot)
            snapshot = newSnapshot

            if let selectedDeviceID,
               !newSnapshot.allUSBNodes.contains(where: { $0.id == selectedDeviceID }) {
                self.selectedDeviceID = nil
                selectedDeviceRowCenter = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false

        if needsRefreshAfterCurrentLoad {
            needsRefreshAfterCurrentLoad = false
            await refresh(force: true)
        }
    }

    func select(_ device: USBNode, openDetail: Bool = true) {
        if selectedDeviceID == device.id {
            selectedDeviceID = nil
            selectedDeviceRowCenter = nil
            return
        }
        selectedDeviceID = device.id
        if openDetail {
            mode = .detail
        }
    }

    func updateSelectedDeviceRowCenter(_ center: CGFloat?) {
        guard selectedDeviceRowCenter != center else { return }
        selectedDeviceRowCenter = center
    }

    func copySelectedDeviceInfo() {
        guard let selectedDevice else { return }
        let language = LanguageOption.currentResolved
        let lines = [
            "\(L10n.text(.name, language)): \(selectedDevice.localizedName(language: language))",
            "\(L10n.text(.vendor, language)): \(selectedDevice.vendor ?? L10n.text(.unknown, language))",
            "\(L10n.text(.kind, language)): \(selectedDevice.kind.localizedLabel(language: language))",
            "\(L10n.text(.speed, language)): \(selectedDevice.speed ?? L10n.text(.unknown, language))",
            "\(L10n.text(.power, language)): \(selectedDevice.powerWatts.map(USBFormatters.watts) ?? L10n.text(.unknown, language))",
            "\(L10n.text(.currentRequired, language)): \(USBFormatters.milliamps(selectedDevice.currentRequiredMA, language: language))",
            "\(L10n.text(.currentAvailable, language)): \(USBFormatters.milliamps(selectedDevice.currentAvailableMA, language: language))",
            "\(L10n.text(.serial, language)): \(selectedDevice.serial ?? L10n.text(.unknown, language))",
            "\(L10n.text(.vidPid, language)): \([selectedDevice.vendorID, selectedDevice.productID].compactMap { $0 }.joined(separator: ":"))",
            "\(L10n.text(.locationID, language)): \(selectedDevice.locationID ?? L10n.text(.unknown, language))"
        ]
        Pasteboard.copy(lines.joined(separator: "\n"))
    }

    func showInFinder(_ volume: USBVolume) {
        do {
            try DiskActions.revealInFinder(volume)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unmount(_ volume: USBVolume) async {
        unmountingVolumeIDs.insert(volume.id)
        removeVolumesFromSnapshot(ids: [volume.id])
        do {
            try await DiskActions.unmount(volume)
            await refreshUntilVolumeDisappears(volume)
        } catch {
            unmountingVolumeIDs.remove(volume.id)
            await refresh(force: true)
            errorMessage = error.localizedDescription
        }
    }

    func clearEvents() {
        events = []
        persistEvents()
    }

    private func captureConnectionChanges(_ newSnapshot: USBSnapshot) {
        let newDevices = newSnapshot.connectedDevices.filter { !$0.isHub }
        let newIDs = Set(newDevices.map(\.id))

        guard !knownDeviceIDs.isEmpty else {
            knownDeviceIDs = newIDs
            return
        }

        let removed = knownDeviceIDs.subtracting(newIDs)
        let added = newIDs.subtracting(knownDeviceIDs)

        for device in newDevices where added.contains(device.id) {
            appendEvent(deviceName: device.name, kind: .connected)
        }

        for removedID in removed {
            appendEvent(deviceName: removedID.components(separatedBy: ".").last ?? L10n.text(.usbDevice, LanguageOption.currentResolved), kind: .disconnected)
        }

        knownDeviceIDs = newIDs
    }

    private func appendEvent(deviceName: String, kind: ConnectionEvent.EventKind) {
        let event = ConnectionEvent(id: UUID(), date: Date(), deviceName: deviceName, kind: kind)
        events.insert(event, at: 0)
        events = Array(events.prefix(24))
        persistEvents()
    }

    private func registerWorkspaceVolumeNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didMountNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh(force: true)
                }
            }
        )
        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didUnmountNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let unmountedPath = (notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL)?.path
                Task { @MainActor in
                    self?.removeUnmountedVolume(mountPoint: unmountedPath)
                    await self?.refresh(force: true)
                }
            }
        )
    }

    private func removeUnmountedVolume(mountPoint unmountedPath: String?) {
        guard let unmountedPath else { return }
        let ids = Set(
            snapshot.externalVolumes
                .filter { $0.mountPoint == unmountedPath }
                .map(\.id)
        )
        removeVolumesFromSnapshot(ids: ids)
    }

    private func refreshUntilVolumeDisappears(_ volume: USBVolume) async {
        for attempt in 0..<5 {
            await refresh(force: true)
            let stillVisible = snapshot.externalVolumes.contains { candidate in
                candidate.id == volume.id || candidate.deviceIdentifier == volume.deviceIdentifier
            }
            if !stillVisible {
                unmountingVolumeIDs.remove(volume.id)
                return
            }

            if attempt < 4 {
                try? await Task.sleep(for: .milliseconds(250))
            }
        }

        removeVolumesFromSnapshot(ids: [volume.id])
        unmountingVolumeIDs.remove(volume.id)
    }

    private func removeVolumesFromSnapshot(ids: Set<USBVolume.ID>) {
        guard !ids.isEmpty else { return }
        let remainingVolumes = snapshot.externalVolumes.filter { !ids.contains($0.id) }
        guard remainingVolumes.count != snapshot.externalVolumes.count else { return }
        snapshot = USBSnapshot(
            hostName: snapshot.hostName,
            usbRoots: snapshot.usbRoots,
            thunderboltPorts: snapshot.thunderboltPorts,
            typeCPorts: snapshot.typeCPorts,
            externalVolumes: remainingVolumes,
            capturedAt: Date(),
            rawJSONString: snapshot.rawJSONString
        )
    }

    private func loadPersistedEvents() -> [ConnectionEvent] {
        guard let data = UserDefaults.standard.data(forKey: eventsKey),
              let decoded = try? JSONDecoder().decode([ConnectionEvent].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private func persistEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: eventsKey)
    }

}

enum USBVolumeMatcher {
    static func matchedVolumes(for device: USBNode, in volumes: [USBVolume], allStorageDevices: [USBNode]) -> [USBVolume] {
        let locationMatches = volumesMatchingLocation(of: device, in: volumes)
        if !locationMatches.isEmpty {
            return locationMatches
        }

        if allStorageDevices.count == 1 {
            return volumes
        }

        let deviceName = normalized(device.name)
        let mediaMatches = volumes.filter { volume in
            let mediaName = normalized(volume.parentDiskMediaName ?? "")
            return !mediaName.isEmpty && (mediaName.contains(deviceName) || deviceName.contains(mediaName))
        }
        return mediaMatches.count == 1 ? mediaMatches : []
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private static func volumesMatchingLocation(of device: USBNode, in volumes: [USBVolume]) -> [USBVolume] {
        let tokens = deviceLocationTokens(device)
        guard !tokens.isEmpty else { return [] }

        return volumes.filter { volume in
            guard let deviceTreePath = volume.deviceTreePath?.lowercased(), !deviceTreePath.isEmpty else {
                return false
            }
            return tokens.contains { token in
                deviceTreePath.contains("@\(token)") || deviceTreePath.contains(token)
            }
        }
    }

    private static func deviceLocationTokens(_ device: USBNode) -> Set<String> {
        var tokens = Set<String>()

        if let locationID = device.locationID {
            tokens.formUnion(locationTokens(from: locationID))
        }

        for key in ["IORegistryEntryLocation", "locationID", "Location ID", "location_id"] {
            if let value = device.properties.first(where: { $0.key == key })?.value {
                tokens.formUnion(locationTokens(from: value))
            }
        }

        return tokens.filter { $0.count >= 6 }
    }

    private static func locationTokens(from value: String) -> Set<String> {
        var tokens = Set<String>()
        let lowercased = value.lowercased()
        let hexDigits = lowercased
            .replacingOccurrences(of: "0x", with: "")
            .filter { $0.isHexDigit }

        if !hexDigits.isEmpty {
            tokens.insert(hexDigits)
            if let hexValue = UInt64(hexDigits, radix: 16) {
                tokens.insert(String(format: "%08llx", hexValue))
            }
        }

        let decimalDigits = lowercased.filter(\.isNumber)
        if !decimalDigits.isEmpty, let decimalValue = UInt64(decimalDigits, radix: 10) {
            tokens.insert(String(format: "%08llx", decimalValue))
        }

        return tokens
    }
}
