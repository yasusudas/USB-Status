import SwiftUI

struct SettingsView: View {
    @AppStorage(LanguageOption.storageKey) private var languageSelection = LanguageOption.system.rawValue
    @Environment(\.appLanguage) private var language
    @State private var launchAtLoginEnabled = LaunchAtLoginController.isEnabled
    @State private var launchAtLoginError: String?
    @State private var updateCheckState = UpdateCheckState.idle
    @State private var isLicenseVisible = false

    private var selectedOption: LanguageOption {
        LanguageOption.fromStored(languageSelection)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.secondary)
                Text(L10n.text(.settingsTitle, language))
                    .font(.title3.weight(.semibold))
            }

            Divider()

            SettingsSection(title: L10n.text(.general, language)) {
                Toggle(
                    isOn: Binding(
                        get: { launchAtLoginEnabled },
                        set: { setLaunchAtLogin($0) }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text(.autostart, language))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text(L10n.text(.launchAtLoginDescription, language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: L10n.text(.language, language)) {
                HStack {
                    Text(L10n.text(.language, language))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    Picker(L10n.text(.language, language), selection: $languageSelection) {
                        ForEach(LanguageOption.allCases) { option in
                            Text(option.localizedName(language: language))
                                .tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 190)
                }

                Text(L10n.text(.languageSettingsDescription, language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsSection(title: L10n.text(.updates, language)) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.text(.currentVersion, language))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text(versionText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        checkForUpdates()
                    } label: {
                        if updateCheckState == .checking {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 18, height: 18)
                        } else {
                            Text(L10n.text(.checkForUpdates, language))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(updateCheckState == .checking)
                }

                if let updateStatusText {
                    Text(updateStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: L10n.text(.license, language)) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isLicenseVisible.toggle()
                    }
                } label: {
                    Text(L10n.text(.showIconLicense, language))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if isLicenseVisible {
                    HStack(spacing: 3) {
                        Link("USB-C", destination: URL(string: "https://icons8.com/icon/K0i398EhYkXg/usb-c")!)
                        Text("icon by")
                            .foregroundStyle(.secondary)
                        Link("Icons8", destination: URL(string: "https://icons8.com")!)
                    }
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .frame(width: 460, alignment: .leading)
        .onAppear {
            launchAtLoginEnabled = LaunchAtLoginController.isEnabled
        }
    }

    private var updateStatusText: String? {
        switch updateCheckState {
        case .idle:
            nil
        case .checking:
            L10n.text(.checkingForUpdates, language)
        case .unavailable:
            L10n.text(.updateCheckUnavailable, language)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
            launchAtLoginEnabled = LaunchAtLoginController.isEnabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginEnabled = LaunchAtLoginController.isEnabled
            launchAtLoginError = L10n.format(.autostartErrorFormat, language, error.localizedDescription)
        }
    }

    private func checkForUpdates() {
        updateCheckState = .checking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateCheckState = .unavailable
        }
    }
}

private enum UpdateCheckState {
    case idle
    case checking
    case unavailable
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 9) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(.primary.opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }
}
