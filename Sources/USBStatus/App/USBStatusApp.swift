import AppKit
import Combine
import Foundation
import SwiftUI

@main
struct USBStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(LanguageOption.storageKey) private var languageSelection = LanguageOption.system.rawValue

    init() {
        SnapshotCLI.exitIfRequested()
    }

    private var language: AppLanguage {
        LanguageOption.fromStored(languageSelection).resolvedLanguage
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(\.appLanguage, language)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = USBStatusStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var detailPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var contextMenu: NSMenu?
    private var statusItemRightClickMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    private let popoverSize = NSSize(width: 420, height: 520)
    private let detailPanelTotalWidth: CGFloat = 418
    private let detailPanelHeight: CGFloat = 500
    private let detailPanelTopInset: CGFloat = 8
    private let deviceListTopInset: CGFloat = 84

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        configureStatusItem()
        configurePopover()
        bindStatusItem()
    }

    private var language: AppLanguage {
        LanguageOption.currentResolved
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image(size: 16)
        button.imagePosition = .imageLeft
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp])
        installStatusItemRightClickMonitor()
        updateStatusItem()
    }

    private func installStatusItemRightClickMonitor() {
        if let statusItemRightClickMonitor {
            NSEvent.removeMonitor(statusItemRightClickMonitor)
        }

        statusItemRightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self, self.handleStatusItemRightMouseDown(event) else {
                return event
            }
            return nil
        }
    }

    private func configurePopover() {
        popover.behavior = .semitransient
        popover.delegate = self
        popover.contentSize = popoverSize
        updatePopoverContent()
    }

    private func bindStatusItem() {
        store.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
                self?.updatePopoverContentIfVisible()
                self?.updateDetailOverlay()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePopoverContentIfVisible()
                self?.updateDetailOverlay()
                self?.updateSettingsWindowContentIfVisible()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(store.$mode, store.$selectedDeviceID, store.$selectedDeviceRowCenter)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDetailOverlay()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        statusItem.button?.title = " \(store.snapshot.deviceCount)"
    }

    private func updatePopoverContentIfVisible() {
        guard popover.isShown else { return }
        updatePopoverContent()
    }

    private func updatePopoverContent() {
        popover.contentViewController = NSHostingController(
            rootView: StatusPanelView(store: store)
                .environment(\.appLanguage, language)
        )
    }

    private func updateSettingsWindowContentIfVisible() {
        guard settingsWindow?.isVisible == true else { return }
        updateSettingsWindowContent()
    }

    private func updateSettingsWindowContent() {
        settingsWindow?.title = L10n.text(.settingsTitle, language)
        settingsWindow?.contentViewController = NSHostingController(
            rootView: SettingsView()
                .environment(\.appLanguage, language)
        )
    }

    private func updateDetailOverlay() {
        guard popover.isShown,
              store.mode == .devices,
              let device = store.selectedDevice,
              let popoverWindow = popover.contentViewController?.view.window,
              let detailFrame = detailPanelFrame(relativeTo: popoverWindow.frame)
        else {
            closeDetailOverlay()
            return
        }

        let panel = detailPanel ?? makeDetailPanel()
        let arrowY = store.selectedDeviceRowCenter.map { $0 + deviceListTopInset - detailPanelTopInset }
        let content = FloatingDeviceDetailPanel(
            store: store,
            device: device,
            volumes: store.volumes(for: device),
            arrowY: arrowY
        )
        .frame(width: detailPanelTotalWidth, height: detailFrame.height)
        .background(Color.clear)
        .environment(\.appLanguage, language)

        panel.contentViewController = NSHostingController(rootView: content)
        if panel.parent == nil {
            popoverWindow.addChildWindow(panel, ordered: .above)
        }
        panel.setFrame(detailFrame, display: true)
        panel.orderFront(nil)
        detailPanel = panel
    }

    private func makeDetailPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: detailPanelTotalWidth, height: detailPanelHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    private func detailPanelFrame(relativeTo popoverFrame: NSRect) -> NSRect? {
        let screenFrame = popover.contentViewController?.view.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let desiredTop = popoverFrame.maxY - detailPanelTopInset
        let height = min(detailPanelHeight, max(420, popoverFrame.height - detailPanelTopInset - 8))
        var origin = NSPoint(
            x: popoverFrame.minX - detailPanelTotalWidth + 4,
            y: desiredTop - height
        )

        if let screenFrame {
            origin.x = max(screenFrame.minX + 8, origin.x)
            origin.y = max(screenFrame.minY + 8, min(origin.y, screenFrame.maxY - height - 8))
        }

        return NSRect(x: origin.x, y: origin.y, width: detailPanelTotalWidth, height: height)
    }

    private func closeDetailOverlay() {
        guard let detailPanel else { return }
        detailPanel.parent?.removeChildWindow(detailPanel)
        detailPanel.orderOut(nil)
        self.detailPanel = nil
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        togglePopover(relativeTo: sender)
    }

    private func handleStatusItemRightMouseDown(_ event: NSEvent) -> Bool {
        guard let button = statusItem.button,
              event.window === button.window
        else {
            return false
        }

        let point = button.convert(event.locationInWindow, from: nil)
        guard button.bounds.contains(point) else {
            return false
        }

        showContextMenu(relativeTo: button, event: event)
        return true
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            closeDetailOverlay()
            popover.performClose(nil)
            return
        }
        popover.contentSize = popoverSize
        updatePopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        updateDetailOverlay()
    }

    func popoverWillClose(_ notification: Notification) {
        closeDetailOverlay()
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton, event: NSEvent) {
        closeDetailOverlay()
        popover.performClose(nil)

        let menu = NSMenu()
        menu.autoenablesItems = false

        let settingsItem = menu.addItem(
            withTitle: L10n.text(.settings, language),
            action: #selector(openSettingsWindow(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.isEnabled = true

        menu.addItem(.separator())

        let quitItem = menu.addItem(
            withTitle: L10n.text(.quit, language),
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.isEnabled = true

        contextMenu = menu
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    @objc private func openSettingsWindow(_ sender: Any?) {
        closeDetailOverlay()
        popover.performClose(nil)

        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        updateSettingsWindowContent()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.text(.settingsTitle, language)
        window.isReleasedWhenClosed = false
        window.center()
        window.collectionBehavior = [.moveToActiveSpace]
        window.tabbingMode = .disallowed
        return window
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
}

enum SnapshotCLI {
    static func exitIfRequested() {
        guard CommandLine.arguments.contains("--snapshot-json") else { return }

        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            do {
                let snapshot = try await USBProfiler().loadSnapshot()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(snapshot)
                if let output = String(data: data, encoding: .utf8) {
                    print(output)
                }
                exit(0)
            } catch {
                fputs("\(error.localizedDescription)\n", stderr)
                exit(1)
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}
