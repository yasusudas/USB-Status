import SwiftUI

struct DeviceListView: View {
    @ObservedObject var store: USBStatusStore
    @Environment(\.appLanguage) private var language
    @State private var selectedRowCenter: CGFloat?

    var body: some View {
        deviceList
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if store.filteredDevices.isEmpty {
                    EmptyStateView(
                        symbol: "cable.connector.slash",
                        title: L10n.text(.noUSBDevices, language),
                        message: store.snapshot.thunderboltPorts.isEmpty
                            ? L10n.text(.noUSBDevicesMessage, language)
                            : L10n.text(.noUSBDevicesWithPortsMessage, language)
                    )
                    .padding(.top, 70)
                } else {
                    ForEach(store.filteredDevices) { device in
                        DeviceRowView(
                            device: device,
                            title: store.displayName(for: device),
                            isSelected: store.selectedDeviceID == device.id
                        ) {
                            store.select(device, openDetail: false)
                        }
                        .background(rowPositionReader(for: device))

                        Divider().opacity(0.28)
                    }
                }
            }
            .padding(.horizontal, 0)
            .padding(.bottom, 8)
        }
        .coordinateSpace(name: DeviceListMetrics.rowCoordinateSpace)
        .onPreferenceChange(DeviceRowCenterPreferenceKey.self) { centers in
            let center = store.selectedDeviceID.flatMap { centers[$0] }
            selectedRowCenter = center
            store.updateSelectedDeviceRowCenter(center)
        }
    }

    @ViewBuilder
    private func rowPositionReader(for device: USBNode) -> some View {
        if store.selectedDeviceID == device.id {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DeviceRowCenterPreferenceKey.self,
                    value: [device.id: proxy.frame(in: .named(DeviceListMetrics.rowCoordinateSpace)).midY]
                )
            }
        }
    }
}

private enum DeviceListMetrics {
    static let rowCoordinateSpace = "USBStatusDeviceListRows"
}

private struct DeviceRowCenterPreferenceKey: PreferenceKey {
    static let defaultValue: [USBNode.ID: CGFloat] = [:]

    static func reduce(value: inout [USBNode.ID: CGFloat], nextValue: () -> [USBNode.ID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct DeviceRowView: View {
    let device: USBNode
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 5)
                .padding(.vertical, 6)

            Image(systemName: device.kind.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary.opacity(0.82))
                .frame(width: 18, height: 18)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if let speed = device.speed {
                        MetricBadge(text: speed, tint: .blue)
                    }
                    if let watts = device.powerWatts {
                        MetricBadge(text: USBFormatters.watts(watts), tint: .green)
                    }
                    Spacer(minLength: 0)
                }

                Text(device.localizedSubtitle(language: language))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.72))
                    .lineLimit(1)

                Text(device.localizedIdentifierSummary(language: language))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            Rectangle()
                .fill(isSelected ? Color.blue.opacity(0.10) : Color.clear)
        )
        .onTapGesture(perform: action)
    }
}

struct FloatingDeviceDetailPanel: View {
    @ObservedObject var store: USBStatusStore
    let device: USBNode
    let volumes: [USBVolume]
    let arrowY: CGFloat?
    @Environment(\.appLanguage) private var language

    private var propertyRows: [(String, String)] {
        [
            (L10n.text(.serial, language), USBFormatters.compact(device.serial, language: language)),
            (L10n.text(.vendor, language), USBFormatters.compact(device.vendor, language: language)),
            (L10n.text(.vidPid, language), [device.vendorID, device.productID].compactMap { $0 }.joined(separator: ":")),
            (L10n.text(.usbVersion, language), USBFormatters.compact(device.usbVersion, language: language)),
            (L10n.text(.speed, language), L10n.localizedSpeedText(USBFormatters.compact(device.speed, language: language), language: language))
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let clampedArrowY = min(max(arrowY ?? 116, 42), max(42, proxy.size.height - 42))

            ZStack(alignment: .topTrailing) {
                BubblePanelShape(arrowY: clampedArrowY)
                    .fill(.regularMaterial)
                    .overlay(
                        BubblePanelShape(arrowY: clampedArrowY)
                            .stroke(.primary.opacity(0.14), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 7) {
                    detailHeader

                    HStack(spacing: 7) {
                        if let speed = device.speed {
                            MetricBadge(text: speed, tint: .blue)
                        }
                        if let watts = device.powerWatts {
                            MetricBadge(text: USBFormatters.watts(watts), tint: .green)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text(.properties, language))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        DetailRows(rows: propertyRows)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text(.powerConsumption, language))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        DetailRows(rows: [
                            (L10n.text(.currentRequired, language), USBFormatters.milliamps(device.currentRequiredMA, language: language)),
                            (L10n.text(.estimatedPower, language), device.powerWatts.map(USBFormatters.watts) ?? "—")
                        ])
                    }

                    Divider()

                    CompactConnectionLogSection(events: store.events)

                    Divider()

                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.text(.volumes, language))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        if volumes.isEmpty {
                            Text(L10n.text(.noVolumes, language))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(volumes) { volume in
                                VolumeCard(store: store, volume: volume, isCompact: true)
                            }
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 26)
                .padding(.vertical, 10)
            }
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        }
    }

    private var detailHeader: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: device.kind.symbolName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.displayName(for: device))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(device.localizedSubtitle(language: language))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                store.selectedDeviceID = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .background(
                Circle()
                    .fill(.thinMaterial)
            )
            .help(L10n.text(.backToDevices, language))
        }
    }
}

private struct BubblePanelShape: Shape {
    let arrowY: CGFloat

    func path(in rect: CGRect) -> Path {
        let arrowWidth: CGFloat = 14
        let arrowHeight: CGFloat = 24
        let radius: CGFloat = 14
        let bodyMaxX = rect.maxX - arrowWidth
        let maxArrowCenter = rect.maxY - radius - arrowHeight / 2
        let minArrowCenter = rect.minY + radius + arrowHeight / 2
        let centerY = min(max(arrowY, minArrowCenter), maxArrowCenter)
        let arrowTop = centerY - arrowHeight / 2
        let arrowBottom = centerY + arrowHeight / 2
        let arrowTipX = rect.maxX - 1

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: bodyMaxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: bodyMaxX, y: rect.minY + radius),
            control: CGPoint(x: bodyMaxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: bodyMaxX, y: arrowTop))
        path.addCurve(
            to: CGPoint(x: arrowTipX, y: centerY),
            control1: CGPoint(x: bodyMaxX + 4, y: arrowTop + 2),
            control2: CGPoint(x: arrowTipX - 2, y: centerY - 8)
        )
        path.addCurve(
            to: CGPoint(x: bodyMaxX, y: arrowBottom),
            control1: CGPoint(x: arrowTipX - 2, y: centerY + 8),
            control2: CGPoint(x: bodyMaxX + 4, y: arrowBottom - 2)
        )
        path.addLine(to: CGPoint(x: bodyMaxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: bodyMaxX - radius, y: rect.maxY),
            control: CGPoint(x: bodyMaxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct CompactConnectionLogSection: View {
    let events: [ConnectionEvent]
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text(.connectionLogs, language))
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            if events.isEmpty {
                Text(L10n.text(.connectionChangesEmpty, language))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 3) {
                    ForEach(events.prefix(5)) { event in
                        HStack(spacing: 5) {
                            Text(event.kind == .connected ? L10n.text(.connected, language) : L10n.text(.disconnected, language))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                            Text(event.deviceName)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(USBFormatters.shortTime(event.date, language: language))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct DetailRows: View {
    let rows: [(String, String)]
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows, id: \.0) { key, value in
                HStack(alignment: .top) {
                    Text(key)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value.isEmpty ? L10n.text(.unknown, language) : value)
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 10, design: .rounded))
            }
        }
    }
}

struct VolumeCard: View {
    @ObservedObject var store: USBStatusStore
    let volume: USBVolume
    var isCompact = false
    @Environment(\.appLanguage) private var language

    private var isUnmounting: Bool {
        store.unmountingVolumeIDs.contains(volume.id)
    }

    private var usedText: String {
        guard let usedBytes = volume.usedBytes, let sizeBytes = volume.sizeBytes else {
            return "—"
        }
        return L10n.format(.usedFormat, language, USBFormatters.bytes(usedBytes), USBFormatters.bytes(sizeBytes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 5 : 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(volume.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Text(USBFormatters.bytes(volume.sizeBytes))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(volume.mountPoint ?? L10n.text(.notMounted, language))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ProgressView(value: volume.usedFraction)
                .progressViewStyle(.linear)
                .tint(.blue)

            Text(usedText)
                .font(.system(size: 10, design: .rounded))

            if !isCompact {
                DetailRows(rows: [
                    (L10n.text(.mountedAt, language), volume.mountPoint ?? L10n.text(.notMounted, language)),
                    (L10n.text(.fileSystem, language), volume.fileSystem ?? L10n.text(.unknown, language)),
                    (L10n.text(.encrypted, language), boolText(volume.encrypted)),
                    (L10n.text(.readOnly, language), boolText(volume.readOnly))
                ])
            }

            HStack(spacing: 6) {
                VolumeActionButton(title: L10n.text(.showInFinder, language), isDisabled: !volume.isMounted || isUnmounting) {
                    store.showInFinder(volume)
                }

                VolumeActionButton(title: L10n.text(.unmount, language), kind: .destructive, isDisabled: !volume.isMounted || isUnmounting) {
                    Task { await store.unmount(volume) }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func boolText(_ value: Bool?) -> String {
        guard let value else { return L10n.text(.unknown, language) }
        return value ? L10n.text(.yes, language) : L10n.text(.no, language)
    }
}

private struct VolumeActionButton: View {
    enum Kind {
        case normal
        case destructive
    }

    let title: String
    var kind: Kind = .normal
    var isDisabled = false
    let action: () -> Void

    @State private var isHovered = false

    private var isDestructiveHovered: Bool {
        kind == .destructive && isHovered && !isDisabled
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(minHeight: 22)
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .opacity(isDisabled ? 0.42 : 1)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var foreground: Color {
        if isDisabled {
            return .secondary
        }
        if isDestructiveHovered {
            return .white
        }
        return .primary
    }

    private var background: Color {
        if isDisabled {
            return Color.primary.opacity(0.05)
        }
        if isDestructiveHovered {
            return .red
        }
        return Color.primary.opacity(isHovered ? 0.12 : 0.08)
    }

    private var border: Color {
        if isDisabled {
            return Color.primary.opacity(0.04)
        }
        if isDestructiveHovered {
            return .red
        }
        return Color.primary.opacity(0.08)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)
        }
        .frame(maxWidth: .infinity)
    }
}
