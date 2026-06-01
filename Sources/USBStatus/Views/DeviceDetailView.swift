import AppKit
import SwiftUI

struct DeviceDetailView: View {
    @ObservedObject var store: USBStatusStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        ScrollView {
            if let device = store.selectedDevice {
                VStack(alignment: .leading, spacing: 14) {
                    detailHeader(device)
                    PropertySection(title: L10n.text(.properties, language), rows: rows(for: device))
                    DetailVolumeSection(store: store, volumes: store.volumes(for: device))
                    ConnectionLogSection(events: store.events, clearAction: store.clearEvents)
                    PropertySection(
                        title: L10n.text(.allReportedFields, language),
                        rows: device.properties.map {
                            (
                                L10n.localizedPropertyKey($0.key, language: language),
                                L10n.localizedValue($0.value, language: language)
                            )
                        }
                    )
                }
                .padding(14)
            } else {
                EmptyStateView(
                    symbol: "info.circle",
                    title: L10n.text(.noDeviceSelected, language),
                    message: L10n.text(.noDeviceSelectedMessage, language)
                )
                .padding(.top, 70)
            }
        }
    }

    private func detailHeader(_ device: USBNode) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: device.kind.symbolName)
                .font(.system(size: 26, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.displayName(for: device))
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(device.localizedSubtitle(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if let speed = device.speed {
                        MetricBadge(text: speed, tint: .blue)
                    }
                    if let watts = device.powerWatts {
                        MetricBadge(text: USBFormatters.watts(watts), tint: .green)
                    }
                    MetricBadge(text: device.kind.localizedLabel(language: language), tint: .purple)
                }
            }

            Spacer()

            IconButton(symbol: "chevron.left", help: L10n.text(.backToDevices, language)) {
                store.mode = .devices
            }
            IconButton(symbol: "doc.on.doc", help: L10n.text(.copyDeviceInfo, language)) {
                store.copySelectedDeviceInfo()
            }
        }
    }

    private func rows(for device: USBNode) -> [(String, String)] {
        [
            (L10n.text(.serial, language), USBFormatters.compact(device.serial, language: language)),
            (L10n.text(.vendor, language), USBFormatters.compact(device.vendor, language: language)),
            (L10n.text(.vidPid, language), [device.vendorID, device.productID].compactMap { $0 }.joined(separator: ":")),
            (L10n.text(.locationID, language), USBFormatters.compact(device.locationID, language: language)),
            (L10n.text(.usbVersion, language), USBFormatters.compact(device.usbVersion, language: language)),
            (L10n.text(.speed, language), L10n.localizedSpeedText(USBFormatters.compact(device.speed, language: language), language: language)),
            (L10n.text(.currentRequired, language), USBFormatters.milliamps(device.currentRequiredMA, language: language)),
            (L10n.text(.currentAvailable, language), USBFormatters.milliamps(device.currentAvailableMA, language: language)),
            (L10n.text(.extraCurrent, language), USBFormatters.milliamps(device.extraOperatingCurrentMA, language: language)),
            (L10n.text(.busPower, language), USBFormatters.milliamps(device.busPowerMA, language: language)),
            (L10n.text(.estimatedPower, language), device.powerWatts.map(USBFormatters.watts) ?? L10n.text(.unknown, language))
        ]
        .filter { !$0.1.isEmpty }
    }
}

struct DetailVolumeSection: View {
    @ObservedObject var store: USBStatusStore
    let volumes: [USBVolume]
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(.volumes, language))
                .font(.headline.weight(.semibold))
            if volumes.isEmpty {
                Text(L10n.text(.noVolumes, language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CardBackground())
            } else {
                ForEach(volumes) { volume in
                    VolumeCard(store: store, volume: volume)
                }
            }
        }
    }
}

struct PropertySection: View {
    let title: String
    let rows: [(String, String)]
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))

            VStack(spacing: 0) {
                ForEach(rows, id: \.0) { key, value in
                    HStack(alignment: .top, spacing: 12) {
                        Text(key)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 132, alignment: .leading)
                        Text(value.isEmpty ? L10n.text(.unknown, language) : value)
                            .font(.caption.monospacedDigit())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, 5)

                    if rows.last?.0 != key {
                        Divider().opacity(0.25)
                    }
                }
            }
            .padding(10)
            .background(CardBackground())
        }
    }
}

struct ConnectionLogSection: View {
    let events: [ConnectionEvent]
    let clearAction: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text(.connectionLogs, language))
                    .font(.headline.weight(.semibold))
                Spacer()
                Button(L10n.text(.clear, language), action: clearAction)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                if events.isEmpty {
                    Text(L10n.text(.connectionChangesEmpty, language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ForEach(events.prefix(8)) { event in
                        HStack {
                            Text(event.kind == .connected ? L10n.text(.connected, language) : L10n.text(.disconnected, language))
                                .font(.caption.weight(.medium))
                            Text(event.deviceName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(USBFormatters.shortDateTime(event.date, language: language))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .padding(10)
            .background(CardBackground())
        }
    }
}

struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.primary.opacity(0.10), lineWidth: 1)
            )
    }
}
