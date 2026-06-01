import SwiftUI

struct PortsView: View {
    let snapshot: USBSnapshot
    @Environment(\.appLanguage) private var language

    private var sortedThunderboltPorts: [ThunderboltPort] {
        snapshot.thunderboltPorts.sorted { lhs, rhs in
            let left = Int(lhs.portNumber.filter(\.isNumber)) ?? Int.max
            let right = Int(rhs.portNumber.filter(\.isNumber)) ?? Int.max
            if left == right {
                return lhs.portNumber.localizedStandardCompare(rhs.portNumber) == .orderedAscending
            }
            return left < right
        }
    }

    private var sortedTypeCPorts: [USBTypeCPort] {
        snapshot.typeCPorts.sorted { lhs, rhs in
            let left = Int(lhs.portNumber.filter(\.isNumber)) ?? Int.max
            let right = Int(rhs.portNumber.filter(\.isNumber)) ?? Int.max
            if left == right {
                return lhs.portNumber.localizedStandardCompare(rhs.portNumber) == .orderedAscending
            }
            return left < right
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: L10n.text(.usbCPorts, language),
                    detail: L10n.format(.portsCountFormat, language, snapshot.typeCPorts.count)
                )

                if snapshot.typeCPorts.isEmpty {
                    EmptyStateView(
                        symbol: "cable.connector.slash",
                        title: L10n.text(.noPortData, language),
                        message: L10n.text(.noPortDataMessage, language)
                    )
                    .padding(.vertical, 16)
                } else {
                    ForEach(sortedTypeCPorts) { port in
                        USBTypeCPortRow(port: port)
                    }
                }

                SectionHeader(
                    title: L10n.text(.thunderboltPorts, language),
                    detail: L10n.format(.portsCountFormat, language, snapshot.thunderboltPorts.count)
                )

                if snapshot.thunderboltPorts.isEmpty {
                    EmptyStateView(
                        symbol: "bolt.horizontal.circle",
                        title: L10n.text(.noPortData, language),
                        message: L10n.text(.noPortDataMessage, language)
                    )
                    .padding(.vertical, 26)
                } else {
                    ForEach(sortedThunderboltPorts) { port in
                        ThunderboltPortRow(port: port)
                    }
                }

                SectionHeader(
                    title: L10n.text(.usbDeviceTree, language),
                    detail: L10n.format(.rootsCountFormat, language, snapshot.usbRoots.count)
                )

                if snapshot.usbRoots.isEmpty {
                    Text(L10n.text(.noUSBTreeMessage, language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CardBackground())
                } else {
                    ForEach(snapshot.usbRoots) { root in
                        USBTreeNodeView(node: root)
                    }
                }
            }
            .padding(14)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
            Text(detail.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }
}

struct USBTypeCPortRow: View {
    let port: USBTypeCPort
    @Environment(\.appLanguage) private var language

    private var symbolName: String {
        if port.powerWatts != nil {
            return "powerplug"
        }
        if port.dataRate != nil {
            return "externaldrive"
        }
        return "cable.connector"
    }

    private var localizedDetail: String {
        guard let detail = port.detail, !detail.isEmpty else {
            return port.isConnected ? L10n.text(.active, language) : L10n.text(.noDevicesConnected, language)
        }
        return detail
            .components(separatedBy: " · ")
            .map { part in
                let deviceName = L10n.localizedDeviceName(part, language: language)
                if deviceName != part { return deviceName }
                return L10n.localizedValue(part, language: language)
            }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("P\(port.portNumber)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                Image(systemName: symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.localizedDeviceName(port.deviceName, language: language))
                        .font(.callout.weight(.semibold))
                    Text(localizedDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let dataRate = port.dataRate {
                    MetricBadge(text: dataRate, tint: .blue)
                }
                if let powerWatts = port.powerWatts {
                    MetricBadge(text: USBFormatters.watts(powerWatts), tint: .green)
                }
            }

            HStack {
                Text(port.isConnected ? L10n.text(.active, language) : L10n.text(.noDevicesConnected, language))
                    .font(.caption)
                    .foregroundStyle(port.isConnected ? Color.green : Color.secondary)
                Spacer()
                if let serial = port.serial, !serial.isEmpty {
                    Text("SN \(serial)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(CardBackground())
    }
}

struct ThunderboltPortRow: View {
    let port: ThunderboltPort
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("P\(port.portNumber)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                Image(systemName: "bolt.horizontal")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(port.busName)
                        .font(.callout.weight(.semibold))
                    Text(port.deviceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let speed = port.speed {
                    MetricBadge(text: speed, tint: .blue)
                }
            }

            HStack {
                Text(L10n.localizedThunderboltStatus(port.status, language: language))
                    .font(.caption)
                    .foregroundStyle(port.status.localizedCaseInsensitiveContains("no devices") ? Color.secondary : Color.green)
                Spacer()
                if let route = port.route {
                    Text(L10n.format(.routeFormat, language, route))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(CardBackground())
    }
}

struct USBTreeNodeView: View {
    let node: USBNode
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: node.kind.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(node.localizedName(language: language))
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if let speed = node.speed {
                    MetricBadge(text: speed, tint: .blue)
                }
            }
            Text(node.localizedIdentifierSummary(language: language))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 26)

            if !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(node.children) { child in
                        USBTreeNodeView(node: child)
                            .padding(.leading, 14)
                    }
                }
            }
        }
        .padding(10)
        .background(CardBackground())
    }
}
