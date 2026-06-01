import AppKit
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var store: USBStatusStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)
            modePicker
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 420, height: 520)
        .background(panelBackground)
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: 28, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.primary.opacity(0.18), lineWidth: 1)
                    )
                Image(nsImage: MenuBarIcon.image(size: 16))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(store.snapshot.hostName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(L10n.format(.updatedFormat, language, USBFormatters.shortTime(store.snapshot.capturedAt, language: language)))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 5)

            MetricBadge(text: L10n.format(.deviceCountFormat, language, store.snapshot.deviceCount), tint: .blue)
            MetricBadge(text: L10n.format(.hubCountFormat, language, store.snapshot.hubCount), tint: .indigo)
            MetricBadge(text: USBFormatters.watts(store.snapshot.estimatedWatts), tint: .green)
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 7)
    }

    private var modePicker: some View {
        ModeSegmentedControl(selection: $store.mode)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        switch store.mode {
        case .devices:
            DeviceListView(store: store)
        case .ports:
            PortsView(snapshot: store.snapshot)
        case .detail:
            DeviceDetailView(store: store)
        }
    }

    private var panelBackground: some View {
        ZStack {
            Color(nsColor: colorScheme == .dark ? .controlBackgroundColor : .windowBackgroundColor)
            Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035)
        }
    }

}

struct ModeSegmentedControl: View {
    @Binding var selection: PanelMode
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: 2) {
                ForEach(PanelMode.allCases) { mode in
                    Button {
                        selection = mode
                    } label: {
                        Text(mode.localizedTitle(language: language))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(selection == mode ? Color.white : Color.primary.opacity(0.72))
                            .frame(width: 62, height: 22)
                            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(selection == mode ? Color.accentColor : Color.clear)
                    )
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )

            Spacer(minLength: 0)
        }
        .accessibilityLabel(L10n.text(.view, language))
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.thinMaterial)
        )
        .help(help)
    }
}

struct MetricBadge: View {
    let text: String
    let tint: Color
    @Environment(\.appLanguage) private var language

    var body: some View {
        Text(L10n.localizedSpeedText(text, language: language))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tint.opacity(0.16))
                    .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
            )
            .foregroundStyle(tint)
    }
}
