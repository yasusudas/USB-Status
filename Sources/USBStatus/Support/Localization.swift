import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    case chinese = "zh-Hans"
    case korean = "ko"

    var id: String { rawValue }

    static var systemResolved: AppLanguage {
        let lowercased = Locale.preferredLanguages.first?.lowercased() ?? ""
        if lowercased.hasPrefix("ja") { return .japanese }
        if lowercased.hasPrefix("en") { return .english }
        if lowercased.hasPrefix("zh") { return .chinese }
        if lowercased.hasPrefix("ko") { return .korean }
        return .english
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

enum LanguageOption: String, CaseIterable, Identifiable {
    case system
    case japanese
    case english
    case chinese
    case korean

    static let storageKey = "USBStatus.languageOption"

    var id: String { rawValue }

    static func fromStored(_ rawValue: String) -> LanguageOption {
        LanguageOption(rawValue: rawValue) ?? .system
    }

    static var currentResolved: AppLanguage {
        fromStored(UserDefaults.standard.string(forKey: storageKey) ?? LanguageOption.system.rawValue).resolvedLanguage
    }

    var resolvedLanguage: AppLanguage {
        switch self {
        case .system:
            AppLanguage.systemResolved
        case .japanese:
            .japanese
        case .english:
            .english
        case .chinese:
            .chinese
        case .korean:
            .korean
        }
    }

    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .system:
            L10n.format(.systemDefaultFormat, language, resolvedLanguage.localizedName(language: language))
        case .japanese:
            AppLanguage.japanese.localizedName(language: language)
        case .english:
            AppLanguage.english.localizedName(language: language)
        case .chinese:
            AppLanguage.chinese.localizedName(language: language)
        case .korean:
            AppLanguage.korean.localizedName(language: language)
        }
    }
}

extension AppLanguage {
    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .japanese:
            L10n.text(.languageJapanese, language)
        case .english:
            L10n.text(.languageEnglish, language)
        case .chinese:
            L10n.text(.languageChinese, language)
        case .korean:
            L10n.text(.languageKorean, language)
        }
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = LanguageOption.currentResolved
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

enum L10nKey: String {
    case allReportedFields
    case active
    case activeCable
    case autostart
    case autostartErrorFormat
    case backToDevices
    case busPower
    case cable
    case chargingCable
    case clear
    case connection
    case connectionChangesEmpty
    case connectionLogs
    case connected
    case copyDeviceInfo
    case current
    case currentAvailable
    case currentRequired
    case currentVersion
    case checkForUpdates
    case checkingForUpdates
    case devices
    case deviceCountFormat
    case disconnected
    case estimatedPower
    case extraCurrent
    case encrypted
    case fileSystem
    case general
    case hubs
    case hubCountFormat
    case info
    case kind
    case language
    case languageChinese
    case languageEnglish
    case languageJapanese
    case languageKorean
    case languageSettingsDescription
    case launchAtLoginDescription
    case license
    case locationID
    case maximumFormat
    case mountedAt
    case name
    case negotiatedPower
    case noDeviceSelected
    case noDeviceSelectedMessage
    case noHardwareIdentifier
    case noPortData
    case noPortDataMessage
    case noUSBDevices
    case noUSBDevicesMessage
    case noUSBDevicesWithPortsMessage
    case noUSBTreeMessage
    case noVolumes
    case noDevicesConnected
    case notMounted
    case no
    case passiveCable
    case ports
    case portsCountFormat
    case power
    case powerConsumption
    case powerIn
    case powerSource
    case properties
    case quit
    case refresh
    case readOnly
    case rootsCountFormat
    case routeFormat
    case search
    case serial
    case settings
    case settingsTitle
    case showIconLicense
    case showInFinder
    case speed
    case systemDefaultFormat
    case transports
    case thunderboltPorts
    case unknown
    case unmount
    case updatedFormat
    case updateCheckUnavailable
    case updates
    case usbCPower
    case usbCChargingCable
    case usbCConnection
    case usbCPorts
    case usbDevice
    case usbDeviceTree
    case usbHub
    case usbVersion
    case vendor
    case vidPid
    case view
    case voltage
    case volumes
    case usedFormat
    case yes

    case kindController
    case kindHub
    case kindStorage
    case kindDisplay
    case kindMobile
    case kindInput
    case kindAudio
    case kindNetwork
    case kindPower
    case kindDevice
}

enum L10n {
    static func text(_ key: L10nKey, _ language: AppLanguage) -> String {
        strings[key]?[language] ?? strings[key]?[.english] ?? key.rawValue
    }

    static func format(_ key: L10nKey, _ language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: text(key, language), locale: language.locale, arguments: arguments)
    }

    static func localizedPropertyKey(_ key: String, language: AppLanguage) -> String {
        switch key {
        case "Bus Power":
            text(.busPower, language)
        case "Cable":
            text(.cable, language)
        case "Connection":
            text(.connection, language)
        case "Current":
            text(.current, language)
        case "Current Available":
            text(.currentAvailable, language)
        case "Current Required":
            text(.currentRequired, language)
        case "Detected Role":
            text(.kindStorage, language)
        case "Estimated Power":
            text(.estimatedPower, language)
        case "Extra Current":
            text(.extraCurrent, language)
        case "Location ID":
            text(.locationID, language)
        case "Negotiated Power":
            text(.negotiatedPower, language)
        case "Port":
            text(.ports, language)
        case "Power Source":
            text(.powerSource, language)
        case "Serial":
            text(.serial, language)
        case "Transports":
            text(.transports, language)
        case "USB Speed":
            text(.speed, language)
        case "USB Version":
            text(.usbVersion, language)
        case "Vendor":
            text(.vendor, language)
        case "VID/PID":
            text(.vidPid, language)
        case "Voltage":
            text(.voltage, language)
        default:
            key
        }
    }

    static func localizedSpeedText(_ text: String, language: AppLanguage) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("up to ") {
            let value = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            return format(.maximumFormat, language, value)
        }
        return trimmed
    }

    static func localizedValue(_ value: String, language: AppLanguage) -> String {
        switch value {
        case "Active":
            text(.active, language)
        case "Active Cable":
            text(.activeCable, language)
        case "Charging cable":
            text(.chargingCable, language)
        case "External Storage":
            text(.kindStorage, language)
        case "No devices connected":
            text(.noDevicesConnected, language)
        case "Passive Cable":
            text(.passiveCable, language)
        case "Power In":
            text(.powerIn, language)
        case "Unknown":
            text(.unknown, language)
        default:
            localizedSpeedText(value, language: language)
        }
    }

    static func localizedDeviceName(_ name: String, language: AppLanguage) -> String {
        switch name {
        case "IORegistry USB Devices":
            text(.usbDeviceTree, language)
        case "USB Device":
            text(.usbDevice, language)
        case "USB-C Power":
            text(.usbCPower, language)
        case "USB-C Charging Cable":
            text(.usbCChargingCable, language)
        case "USB-C Connection":
            text(.usbCConnection, language)
        case "No devices connected":
            text(.noDevicesConnected, language)
        default:
            name
        }
    }

    static func localizedThunderboltStatus(_ status: String, language: AppLanguage) -> String {
        if status.localizedCaseInsensitiveContains("no devices") {
            return text(.noDevicesConnected, language)
        }
        return status
    }

    private static let strings: [L10nKey: [AppLanguage: String]] = [
        .allReportedFields: [
            .japanese: "すべての取得フィールド",
            .english: "All reported fields",
            .chinese: "所有报告字段",
            .korean: "모든 보고 필드"
        ],
        .active: [
            .japanese: "アクティブ",
            .english: "Active",
            .chinese: "活动",
            .korean: "활성"
        ],
        .activeCable: [
            .japanese: "アクティブケーブル",
            .english: "Active Cable",
            .chinese: "有源线缆",
            .korean: "액티브 케이블"
        ],
        .autostart: [
            .japanese: "自動起動",
            .english: "Autostart",
            .chinese: "自动启动",
            .korean: "자동 시작"
        ],
        .autostartErrorFormat: [
            .japanese: "自動起動を変更できませんでした: %@",
            .english: "Autostart could not be changed: %@",
            .chinese: "无法更改自动启动: %@",
            .korean: "자동 시작을 변경할 수 없습니다: %@"
        ],
        .backToDevices: [
            .japanese: "デバイス一覧へ戻る",
            .english: "Back to devices",
            .chinese: "返回设备列表",
            .korean: "기기 목록으로 돌아가기"
        ],
        .busPower: [
            .japanese: "バス電力",
            .english: "Bus Power",
            .chinese: "总线电源",
            .korean: "버스 전원"
        ],
        .cable: [
            .japanese: "ケーブル",
            .english: "Cable",
            .chinese: "线缆",
            .korean: "케이블"
        ],
        .chargingCable: [
            .japanese: "充電ケーブル",
            .english: "Charging cable",
            .chinese: "充电线缆",
            .korean: "충전 케이블"
        ],
        .checkForUpdates: [
            .japanese: "アップデートを確認",
            .english: "Check for Updates",
            .chinese: "检查更新",
            .korean: "업데이트 확인"
        ],
        .checkingForUpdates: [
            .japanese: "アップデートを確認中...",
            .english: "Checking for updates...",
            .chinese: "正在检查更新...",
            .korean: "업데이트 확인 중..."
        ],
        .clear: [
            .japanese: "消去",
            .english: "Clear",
            .chinese: "清除",
            .korean: "지우기"
        ],
        .connection: [
            .japanese: "接続",
            .english: "Connection",
            .chinese: "连接",
            .korean: "연결"
        ],
        .connectionChangesEmpty: [
            .japanese: "アプリの実行中に接続の変化がここに表示されます。",
            .english: "Connection changes will appear here while the app is running.",
            .chinese: "应用运行时，连接变化会显示在这里。",
            .korean: "앱이 실행 중일 때 연결 변경 사항이 여기에 표시됩니다."
        ],
        .connectionLogs: [
            .japanese: "接続ログ",
            .english: "Connection Logs",
            .chinese: "连接日志",
            .korean: "연결 로그"
        ],
        .connected: [
            .japanese: "接続 ↑",
            .english: "Connected ↑",
            .chinese: "已连接 ↑",
            .korean: "연결됨 ↑"
        ],
        .copyDeviceInfo: [
            .japanese: "デバイス情報をコピー",
            .english: "Copy device info",
            .chinese: "复制设备信息",
            .korean: "기기 정보 복사"
        ],
        .current: [
            .japanese: "電流",
            .english: "Current",
            .chinese: "电流",
            .korean: "전류"
        ],
        .currentAvailable: [
            .japanese: "利用可能電流",
            .english: "Current Available",
            .chinese: "可用电流",
            .korean: "사용 가능 전류"
        ],
        .currentRequired: [
            .japanese: "必要電流",
            .english: "Current Required",
            .chinese: "所需电流",
            .korean: "필요 전류"
        ],
        .currentVersion: [
            .japanese: "現在のバージョン",
            .english: "Current Version",
            .chinese: "当前版本",
            .korean: "현재 버전"
        ],
        .devices: [
            .japanese: "デバイス",
            .english: "Devices",
            .chinese: "设备",
            .korean: "기기"
        ],
        .deviceCountFormat: [
            .japanese: "%d 台",
            .english: "%d devices",
            .chinese: "%d 台设备",
            .korean: "%d개 기기"
        ],
        .disconnected: [
            .japanese: "切断 ↓",
            .english: "Disconnected ↓",
            .chinese: "已断开 ↓",
            .korean: "연결 해제됨 ↓"
        ],
        .estimatedPower: [
            .japanese: "推定電力",
            .english: "Estimated Power",
            .chinese: "估算功率",
            .korean: "예상 전력"
        ],
        .extraCurrent: [
            .japanese: "追加電流",
            .english: "Extra Current",
            .chinese: "额外电流",
            .korean: "추가 전류"
        ],
        .encrypted: [
            .japanese: "暗号化",
            .english: "Encrypted",
            .chinese: "已加密",
            .korean: "암호화"
        ],
        .fileSystem: [
            .japanese: "ファイルシステム",
            .english: "File system",
            .chinese: "文件系统",
            .korean: "파일 시스템"
        ],
        .general: [
            .japanese: "一般",
            .english: "General",
            .chinese: "通用",
            .korean: "일반"
        ],
        .hubs: [
            .japanese: "ハブ",
            .english: "Hubs",
            .chinese: "集线器",
            .korean: "허브"
        ],
        .hubCountFormat: [
            .japanese: "%d ハブ",
            .english: "%d hubs",
            .chinese: "%d 个集线器",
            .korean: "%d개 허브"
        ],
        .info: [
            .japanese: "情報",
            .english: "Info",
            .chinese: "信息",
            .korean: "정보"
        ],
        .kind: [
            .japanese: "種類",
            .english: "Kind",
            .chinese: "类型",
            .korean: "종류"
        ],
        .language: [
            .japanese: "言語",
            .english: "Language",
            .chinese: "语言",
            .korean: "언어"
        ],
        .languageChinese: [
            .japanese: "中国語",
            .english: "Chinese",
            .chinese: "中文",
            .korean: "중국어"
        ],
        .languageEnglish: [
            .japanese: "英語",
            .english: "English",
            .chinese: "英语",
            .korean: "영어"
        ],
        .languageJapanese: [
            .japanese: "日本語",
            .english: "Japanese",
            .chinese: "日语",
            .korean: "일본어"
        ],
        .languageKorean: [
            .japanese: "韓国語",
            .english: "Korean",
            .chinese: "韩语",
            .korean: "한국어"
        ],
        .languageSettingsDescription: [
            .japanese: "「システム設定」は、端末の優先言語が日本語・英語・中国語・韓国語のときその言語を使い、それ以外では英語を使います。",
            .english: "System Default follows Japanese, English, Chinese, or Korean device languages and falls back to English for other languages.",
            .chinese: "“系统默认”会跟随日语、英语、中文或韩语的设备语言；其他语言会回退到英语。",
            .korean: "시스템 기본값은 기기의 일본어, 영어, 중국어, 한국어 설정을 따르며, 그 외 언어는 영어로 표시합니다."
        ],
        .launchAtLoginDescription: [
            .japanese: "Mac にログインしたときに USB Status を自動起動します。",
            .english: "Open USB Status automatically when you log in to your Mac.",
            .chinese: "登录 Mac 时自动打开 USB Status。",
            .korean: "Mac에 로그인할 때 USB Status를 자동으로 엽니다."
        ],
        .license: [
            .japanese: "ライセンス",
            .english: "License",
            .chinese: "许可证",
            .korean: "라이선스"
        ],
        .locationID: [
            .japanese: "位置 ID",
            .english: "Location ID",
            .chinese: "位置 ID",
            .korean: "위치 ID"
        ],
        .maximumFormat: [
            .japanese: "最大 %@",
            .english: "Max %@",
            .chinese: "最大 %@",
            .korean: "최대 %@"
        ],
        .mountedAt: [
            .japanese: "マウント先",
            .english: "Mounted at",
            .chinese: "挂载位置",
            .korean: "마운트 위치"
        ],
        .name: [
            .japanese: "名前",
            .english: "Name",
            .chinese: "名称",
            .korean: "이름"
        ],
        .negotiatedPower: [
            .japanese: "交渉済み電力",
            .english: "Negotiated Power",
            .chinese: "协商功率",
            .korean: "협상된 전력"
        ],
        .noDeviceSelected: [
            .japanese: "デバイス未選択",
            .english: "No device selected",
            .chinese: "未选择设备",
            .korean: "선택된 기기 없음"
        ],
        .noDeviceSelectedMessage: [
            .japanese: "接続中の USB デバイスを選択すると、取得されたすべてのフィールドを確認できます。",
            .english: "Select a connected USB device to inspect every reported field.",
            .chinese: "选择已连接的 USB 设备以查看所有报告字段。",
            .korean: "연결된 USB 기기를 선택하면 보고된 모든 필드를 확인할 수 있습니다."
        ],
        .noHardwareIdentifier: [
            .japanese: "ハードウェア識別子なし",
            .english: "No hardware identifier",
            .chinese: "没有硬件标识符",
            .korean: "하드웨어 식별자 없음"
        ],
        .noPortData: [
            .japanese: "ポートデータなし",
            .english: "No port data",
            .chinese: "没有端口数据",
            .korean: "포트 데이터 없음"
        ],
        .noPortDataMessage: [
            .japanese: "システム情報から Thunderbolt または USB4 ポート情報が報告されませんでした。",
            .english: "System Information did not report Thunderbolt or USB4 port records.",
            .chinese: "系统信息未报告 Thunderbolt 或 USB4 端口记录。",
            .korean: "시스템 정보에서 Thunderbolt 또는 USB4 포트 기록을 보고하지 않았습니다."
        ],
        .noUSBDevices: [
            .japanese: "USB デバイスなし",
            .english: "No USB devices",
            .chinese: "没有 USB 设备",
            .korean: "USB 기기 없음"
        ],
        .noUSBDevicesMessage: [
            .japanese: "現在の USB デバイスはシステム情報から報告されませんでした。",
            .english: "No current USB devices were reported by System Information.",
            .chinese: "系统信息未报告当前 USB 设备。",
            .korean: "시스템 정보에서 현재 USB 기기를 보고하지 않았습니다."
        ],
        .noUSBDevicesWithPortsMessage: [
            .japanese: "USB デバイスは空です。Thunderbolt / USB4 ポート状態はポートで確認できます。",
            .english: "USB devices are empty. Thunderbolt / USB4 port status is available in Ports.",
            .chinese: "USB 设备为空。可在端口中查看 Thunderbolt / USB4 端口状态。",
            .korean: "USB 기기 목록이 비어 있습니다. 포트에서 Thunderbolt / USB4 포트 상태를 확인할 수 있습니다."
        ],
        .noUSBTreeMessage: [
            .japanese: "USB ツリーはシステム情報から報告されませんでした。",
            .english: "No USB tree was reported by System Information.",
            .chinese: "系统信息未报告 USB 树。",
            .korean: "시스템 정보에서 USB 트리를 보고하지 않았습니다."
        ],
        .noVolumes: [
            .japanese: "このデバイスのマウント済みボリュームはありません。",
            .english: "No mounted volumes for this device.",
            .chinese: "此设备没有已挂载的卷。",
            .korean: "이 기기에 마운트된 볼륨이 없습니다."
        ],
        .noDevicesConnected: [
            .japanese: "デバイス未接続",
            .english: "No devices connected",
            .chinese: "没有设备连接",
            .korean: "연결된 기기 없음"
        ],
        .notMounted: [
            .japanese: "未マウント",
            .english: "Not mounted",
            .chinese: "未挂载",
            .korean: "마운트되지 않음"
        ],
        .no: [
            .japanese: "いいえ",
            .english: "No",
            .chinese: "否",
            .korean: "아니요"
        ],
        .passiveCable: [
            .japanese: "パッシブケーブル",
            .english: "Passive Cable",
            .chinese: "无源线缆",
            .korean: "패시브 케이블"
        ],
        .ports: [
            .japanese: "ポート",
            .english: "Ports",
            .chinese: "端口",
            .korean: "포트"
        ],
        .portsCountFormat: [
            .japanese: "%d ポート",
            .english: "%d ports",
            .chinese: "%d 个端口",
            .korean: "%d개 포트"
        ],
        .power: [
            .japanese: "電力",
            .english: "Power",
            .chinese: "电源",
            .korean: "전력"
        ],
        .powerConsumption: [
            .japanese: "消費電力",
            .english: "Power consumption",
            .chinese: "功耗",
            .korean: "전력 소비"
        ],
        .powerIn: [
            .japanese: "給電中",
            .english: "Power In",
            .chinese: "供电输入",
            .korean: "전원 입력"
        ],
        .powerSource: [
            .japanese: "電源ソース",
            .english: "Power Source",
            .chinese: "电源来源",
            .korean: "전원 소스"
        ],
        .properties: [
            .japanese: "プロパティ",
            .english: "Properties",
            .chinese: "属性",
            .korean: "속성"
        ],
        .quit: [
            .japanese: "終了",
            .english: "Quit",
            .chinese: "退出",
            .korean: "종료"
        ],
        .refresh: [
            .japanese: "更新",
            .english: "Refresh",
            .chinese: "刷新",
            .korean: "새로 고침"
        ],
        .readOnly: [
            .japanese: "読み取り専用",
            .english: "Read-only",
            .chinese: "只读",
            .korean: "읽기 전용"
        ],
        .rootsCountFormat: [
            .japanese: "%d ルート",
            .english: "%d roots",
            .chinese: "%d 个根",
            .korean: "%d개 루트"
        ],
        .routeFormat: [
            .japanese: "ルート %@",
            .english: "Route %@",
            .chinese: "路由 %@",
            .korean: "경로 %@"
        ],
        .search: [
            .japanese: "検索",
            .english: "Search",
            .chinese: "搜索",
            .korean: "검색"
        ],
        .serial: [
            .japanese: "シリアル",
            .english: "Serial",
            .chinese: "序列号",
            .korean: "일련번호"
        ],
        .settings: [
            .japanese: "設定",
            .english: "Settings",
            .chinese: "设置",
            .korean: "설정"
        ],
        .settingsTitle: [
            .japanese: "USB Status 設定",
            .english: "USB Status Settings",
            .chinese: "USB Status 设置",
            .korean: "USB Status 설정"
        ],
        .showIconLicense: [
            .japanese: "アイコンのライセンスを表示",
            .english: "Show Icon License",
            .chinese: "显示图标许可证",
            .korean: "아이콘 라이선스 보기"
        ],
        .showInFinder: [
            .japanese: "Finderで表示",
            .english: "Show in Finder",
            .chinese: "在 Finder 中显示",
            .korean: "Finder에서 보기"
        ],
        .speed: [
            .japanese: "速度",
            .english: "Speed",
            .chinese: "速度",
            .korean: "속도"
        ],
        .systemDefaultFormat: [
            .japanese: "システム設定（%@）",
            .english: "System Default (%@)",
            .chinese: "系统默认（%@）",
            .korean: "시스템 기본값(%@)"
        ],
        .transports: [
            .japanese: "転送",
            .english: "Transports",
            .chinese: "传输",
            .korean: "전송"
        ],
        .thunderboltPorts: [
            .japanese: "Thunderbolt / USB4 ポート",
            .english: "Thunderbolt / USB4 Ports",
            .chinese: "Thunderbolt / USB4 端口",
            .korean: "Thunderbolt / USB4 포트"
        ],
        .unknown: [
            .japanese: "不明",
            .english: "Unknown",
            .chinese: "未知",
            .korean: "알 수 없음"
        ],
        .unmount: [
            .japanese: "アンマウント",
            .english: "Unmount",
            .chinese: "卸载",
            .korean: "마운트 해제"
        ],
        .updatedFormat: [
            .japanese: "更新 %@",
            .english: "Updated %@",
            .chinese: "已更新 %@",
            .korean: "업데이트 %@"
        ],
        .updateCheckUnavailable: [
            .japanese: "このローカルビルドにはアップデート配信元が設定されていません。",
            .english: "This local build does not have an update feed configured.",
            .chinese: "此本地构建尚未配置更新源。",
            .korean: "이 로컬 빌드에는 업데이트 피드가 설정되어 있지 않습니다."
        ],
        .updates: [
            .japanese: "アップデート",
            .english: "Updates",
            .chinese: "更新",
            .korean: "업데이트"
        ],
        .usbCPower: [
            .japanese: "USB-C 電源",
            .english: "USB-C Power",
            .chinese: "USB-C 电源",
            .korean: "USB-C 전원"
        ],
        .usbCChargingCable: [
            .japanese: "USB-C 充電ケーブル",
            .english: "USB-C Charging Cable",
            .chinese: "USB-C 充电线缆",
            .korean: "USB-C 충전 케이블"
        ],
        .usbCConnection: [
            .japanese: "USB-C 接続",
            .english: "USB-C Connection",
            .chinese: "USB-C 连接",
            .korean: "USB-C 연결"
        ],
        .usbCPorts: [
            .japanese: "USB-C ポート",
            .english: "USB-C Ports",
            .chinese: "USB-C 端口",
            .korean: "USB-C 포트"
        ],
        .usbDevice: [
            .japanese: "USB デバイス",
            .english: "USB Device",
            .chinese: "USB 设备",
            .korean: "USB 기기"
        ],
        .usbDeviceTree: [
            .japanese: "USB デバイスツリー",
            .english: "USB Device Tree",
            .chinese: "USB 设备树",
            .korean: "USB 기기 트리"
        ],
        .usbHub: [
            .japanese: "USB ハブ",
            .english: "USB Hub",
            .chinese: "USB 集线器",
            .korean: "USB 허브"
        ],
        .usbVersion: [
            .japanese: "USB バージョン",
            .english: "USB Version",
            .chinese: "USB 版本",
            .korean: "USB 버전"
        ],
        .vendor: [
            .japanese: "ベンダー",
            .english: "Vendor",
            .chinese: "供应商",
            .korean: "벤더"
        ],
        .vidPid: [
            .japanese: "VID/PID",
            .english: "VID/PID",
            .chinese: "VID/PID",
            .korean: "VID/PID"
        ],
        .view: [
            .japanese: "表示",
            .english: "View",
            .chinese: "视图",
            .korean: "보기"
        ],
        .voltage: [
            .japanese: "電圧",
            .english: "Voltage",
            .chinese: "电压",
            .korean: "전압"
        ],
        .volumes: [
            .japanese: "ボリューム",
            .english: "Volumes",
            .chinese: "卷",
            .korean: "볼륨"
        ],
        .usedFormat: [
            .japanese: "%@ / %@ 使用中",
            .english: "%@ of %@ used",
            .chinese: "已使用 %@ / %@",
            .korean: "%@ / %@ 사용됨"
        ],
        .yes: [
            .japanese: "はい",
            .english: "Yes",
            .chinese: "是",
            .korean: "예"
        ],
        .kindController: [
            .japanese: "コントローラ",
            .english: "Controller",
            .chinese: "控制器",
            .korean: "컨트롤러"
        ],
        .kindHub: [
            .japanese: "USB ハブ",
            .english: "USB Hub",
            .chinese: "USB 集线器",
            .korean: "USB 허브"
        ],
        .kindStorage: [
            .japanese: "外部ストレージ",
            .english: "External Storage",
            .chinese: "外部存储",
            .korean: "외부 저장 장치"
        ],
        .kindDisplay: [
            .japanese: "ディスプレイ",
            .english: "Display",
            .chinese: "显示器",
            .korean: "디스플레이"
        ],
        .kindMobile: [
            .japanese: "モバイルデバイス",
            .english: "Mobile Device",
            .chinese: "移动设备",
            .korean: "모바일 기기"
        ],
        .kindInput: [
            .japanese: "入力デバイス",
            .english: "Input Device",
            .chinese: "输入设备",
            .korean: "입력 기기"
        ],
        .kindAudio: [
            .japanese: "オーディオデバイス",
            .english: "Audio Device",
            .chinese: "音频设备",
            .korean: "오디오 기기"
        ],
        .kindNetwork: [
            .japanese: "ネットワークアダプタ",
            .english: "Network Adapter",
            .chinese: "网络适配器",
            .korean: "네트워크 어댑터"
        ],
        .kindPower: [
            .japanese: "充電ケーブル",
            .english: "Charging Cable",
            .chinese: "充电线缆",
            .korean: "충전 케이블"
        ],
        .kindDevice: [
            .japanese: "USB デバイス",
            .english: "USB Device",
            .chinese: "USB 设备",
            .korean: "USB 기기"
        ]
    ]
}
