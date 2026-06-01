import Darwin
import Dispatch
import Foundation

enum USBProfilerError: LocalizedError {
    case commandFailed(String)
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            "Command failed: \(message)"
        case .invalidJSON(let message):
            "Invalid system profiler JSON: \(message)"
        }
    }
}

struct USBProfiler {
    func loadSnapshot() async throws -> USBSnapshot {
        try await Task.detached(priority: .userInitiated) {
            let usbJSON = try Self.run("/usr/sbin/system_profiler", arguments: ["SPUSBDataType", "-json"])
            let thunderboltJSON = try Self.run("/usr/sbin/system_profiler", arguments: ["SPThunderboltDataType", "-json"])
            let usbRegistryXML = try Self.run("/usr/sbin/ioreg", arguments: ["-r", "-c", "IOUSBHostDevice", "-a", "-l", "-w0"])
            let typeCPortXML = try Self.run("/usr/sbin/ioreg", arguments: ["-r", "-c", "AppleTCControllerType10", "-a", "-l", "-w0"])
            let diskListXML = (try? Self.run("/usr/sbin/diskutil", arguments: ["list", "-plist", "external", "physical"])) ?? ""

            let usbObject = try Self.decodeObject(usbJSON)
            let thunderboltObject = try Self.decodeObject(thunderboltJSON)
            let usbRegistryObject = (try? Self.decodePlist(usbRegistryXML)) ?? []
            let typeCPortObject = (try? Self.decodePlist(typeCPortXML)) ?? []
            let diskListObject = try? Self.decodePlist(diskListXML)

            let usbRootDictionaries = usbObject["SPUSBDataType"] as? [[String: Any]] ?? []
            let thunderboltDictionaries = thunderboltObject["SPThunderboltDataType"] as? [[String: Any]] ?? []

            var usbRoots = usbRootDictionaries.enumerated().map { index, dictionary in
                Self.parseUSBNode(dictionary, level: 0, path: "usb.\(index)")
            }
            if usbRoots.isEmpty {
                usbRoots = Self.parseIORegistryUSBRoots(usbRegistryObject)
            }

            let powerNodes = Self.parseUSBTypeCPowerNodes(typeCPortObject)
            if !powerNodes.isEmpty {
                usbRoots.append(
                    USBNode(
                        id: "power.usb-c",
                        name: "USB-C Power",
                        vendor: "Apple HPM",
                        productID: nil,
                        vendorID: nil,
                        serial: nil,
                        locationID: nil,
                        usbVersion: "USB-C",
                        speed: nil,
                        currentRequiredMA: nil,
                        currentAvailableMA: nil,
                        extraOperatingCurrentMA: nil,
                        busPowerMA: nil,
                        powerWattsOverride: nil,
                        level: 0,
                        kind: .controller,
                        properties: [USBProperty(key: "Source", value: "IORegistry AppleTCControllerType10")],
                        children: powerNodes
                    )
                )
            }

            let ports = thunderboltDictionaries.enumerated().flatMap { index, dictionary in
                Self.parseThunderboltPorts(dictionary, busIndex: index)
            }
            let typeCPorts = Self.parseUSBTypeCPorts(typeCPortObject, usbRoots: usbRoots)
            let externalVolumes = Self.parseExternalVolumes(diskListObject)

            let raw = Self.joinedRawJSON(
                usbObject: usbObject,
                thunderboltObject: thunderboltObject,
                usbRegistryXML: usbRegistryXML,
                typeCPortXML: typeCPortXML,
                diskListXML: diskListXML
            )
            return USBSnapshot(
                hostName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
                usbRoots: usbRoots,
                thunderboltPorts: ports,
                typeCPorts: typeCPorts,
                externalVolumes: externalVolumes,
                capturedAt: Date(),
                rawJSONString: raw
            )
        }.value
    }

    private static func run(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let stdoutURL = temporaryDirectory.appendingPathComponent("USBStatus-\(UUID().uuidString).stdout")
        let stderrURL = temporaryDirectory.appendingPathComponent("USBStatus-\(UUID().uuidString).stderr")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
        }
        let group = DispatchGroup()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = temporaryDirectory
        process.standardOutput = stdout
        process.standardError = stderr
        process.terminationHandler = { _ in group.leave() }

        group.enter()
        try process.run()
        if group.wait(timeout: .now() + 8) == .timedOut {
            process.terminate()
            if group.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
            throw USBProfilerError.commandFailed("\(executable) \(arguments.joined(separator: " ")) timed out")
        }

        let output = try Data(contentsOf: stdoutURL)
        let error = try Data(contentsOf: stderrURL)

        if process.terminationStatus != 0 {
            let message = String(data: error, encoding: .utf8) ?? "exit \(process.terminationStatus)"
            throw USBProfilerError.commandFailed(message)
        }

        return String(data: output, encoding: .utf8) ?? ""
    }

    private static func decodePlist(_ xml: String) throws -> Any {
        guard let data = xml.data(using: .utf8) else {
            throw USBProfilerError.invalidJSON("plist input is not UTF-8")
        }
        return try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }

    private static func decodeObject(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8) else {
            throw USBProfilerError.invalidJSON("input is not UTF-8")
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw USBProfilerError.invalidJSON("top-level value is not a dictionary")
        }
        return dictionary
    }

    private static func joinedRawJSON(
        usbObject: [String: Any],
        thunderboltObject: [String: Any],
        usbRegistryXML: String,
        typeCPortXML: String,
        diskListXML: String
    ) -> String {
        let object: [String: Any] = [
            "USB": usbObject,
            "ThunderboltUSB4": thunderboltObject,
            "IORegistryUSBXML": usbRegistryXML,
            "IORegistryTypeCPortXML": typeCPortXML,
            "DiskUtilExternalPhysicalXML": diskListXML
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let raw = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return raw
    }

    private static func parseUSBNode(_ dictionary: [String: Any], level: Int, path: String) -> USBNode {
        let childrenDictionaries = dictionary["_items"] as? [[String: Any]] ?? []
        let name = firstString(dictionary, keys: ["_name", "name", "device_name", "device_name_key"]) ?? "USB Device"
        let properties = rawProperties(from: dictionary)
        let children = childrenDictionaries.enumerated().map { index, child in
            parseUSBNode(child, level: level + 1, path: "\(path).\(index)")
        }

        let vendor = firstString(dictionary, keys: ["manufacturer", "vendor_name", "vendor_name_key", "vendor"])
        let productID = firstString(dictionary, keys: ["product_id", "Product ID", "idProduct"])
        let vendorID = firstString(dictionary, keys: ["vendor_id", "Vendor ID", "idVendor"])
        let serial = firstString(dictionary, keys: ["serial_num", "serial", "serial_number", "Serial Number"])
        let locationID = firstString(dictionary, keys: ["location_id", "locationID", "Location ID"])
        let speed = firstString(dictionary, keys: ["speed", "usb_speed", "USB Speed", "current_speed_key"])
        let usbVersion = firstString(dictionary, keys: ["bcd_device", "usb_version", "USB Version"])
        let currentRequired = firstNumber(dictionary, keys: ["current_required", "Current Required (mA)", "current_required_ma"])
        let currentAvailable = firstNumber(dictionary, keys: ["current_available", "Current Available (mA)", "current_available_ma"])
        let extraCurrent = firstNumber(dictionary, keys: ["extra_operating_current", "Extra Operating Current (mA)"])
        let busPower = firstNumber(dictionary, keys: ["bus_power", "Bus Power (mA)"])

        return USBNode(
            id: stableID(
                name: name,
                serial: serial,
                locationID: locationID,
                vendorID: vendorID,
                productID: productID,
                path: path
            ),
            name: name,
            vendor: vendor,
            productID: productID,
            vendorID: vendorID,
            serial: serial,
            locationID: locationID,
            usbVersion: usbVersion,
            speed: speed,
            currentRequiredMA: currentRequired,
            currentAvailableMA: currentAvailable,
            extraOperatingCurrentMA: extraCurrent,
            busPowerMA: busPower,
            powerWattsOverride: nil,
            level: level,
            kind: inferKind(name: name, properties: properties, level: level),
            properties: properties,
            children: children
        )
    }

    private static func parseIORegistryUSBRoots(_ object: Any) -> [USBNode] {
        if let devices = object as? [[String: Any]] {
            let children = devices.enumerated().map { index, dictionary in
                parseIORegistryUSBNode(dictionary, level: 1, path: "ioreg.usb.device.\(index)")
            }
            guard !children.isEmpty else { return [] }
            return [
                USBNode(
                    id: "ioreg.usb.devices",
                    name: "IORegistry USB Devices",
                    vendor: "macOS",
                    productID: nil,
                    vendorID: nil,
                    serial: nil,
                    locationID: nil,
                    usbVersion: nil,
                    speed: nil,
                    currentRequiredMA: nil,
                    currentAvailableMA: nil,
                    extraOperatingCurrentMA: nil,
                    busPowerMA: nil,
                    powerWattsOverride: nil,
                    level: 0,
                    kind: .controller,
                    properties: [USBProperty(key: "Source", value: "IORegistry IOUSBHostDevice")],
                    children: children
                )
            ]
        }

        guard let root = object as? [String: Any] else { return [] }
        let children = root["IORegistryEntryChildren"] as? [[String: Any]] ?? []
        return children.enumerated().compactMap { index, dictionary in
            guard isUSBController(dictionary) else { return nil }
            return parseIORegistryUSBNode(dictionary, level: 0, path: "ioreg.usb.\(index)")
        }
    }

    private static func parseIORegistryUSBNode(_ dictionary: [String: Any], level: Int, path: String) -> USBNode {
        let allChildren = dictionary["IORegistryEntryChildren"] as? [[String: Any]] ?? []
        let relevantChildren = allChildren.enumerated().compactMap { index, child -> USBNode? in
            if isUSBDevice(child) || isUSBController(child) {
                return parseIORegistryUSBNode(child, level: level + 1, path: "\(path).\(index)")
            }
            return nil
        }

        let name = firstString(dictionary, keys: [
            "USB Product Name",
            "kUSBProductString",
            "IORegistryEntryName",
            "Description",
            "IOObjectClass"
        ])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "USB Device"

        var properties = rawProperties(from: dictionary)
        let storageDetected = containsRecursive(dictionary, needles: [
            "IOUSBMassStorage",
            "IOBlockStorage",
            "IOMedia",
            "SCSI",
            "Physical Interconnect\" = \"USB"
        ])
        if storageDetected {
            properties.append(USBProperty(key: "Detected Role", value: "External Storage"))
        }

        let vendor = firstString(dictionary, keys: ["USB Vendor Name", "kUSBVendorString", "Manufacturer", "manufacturer"])
        let productID = firstString(dictionary, keys: ["idProduct", "Product ID", "product_id"])
        let vendorID = firstString(dictionary, keys: ["idVendor", "Vendor ID", "vendor_id"])
        let serial = firstString(dictionary, keys: ["USB Serial Number", "kUSBSerialNumberString", "serial_num"])
        let locationID = firstString(dictionary, keys: ["locationID", "Location ID", "location_id"])
        let speed = speedDescription(from: dictionary)
        let usbVersion = usbVersionDescription(from: dictionary)
        let currentRequired = firstNumber(dictionary, keys: ["UsbPowerSinkAllocation", "current_required", "Current Required (mA)"])

        let kind: USBNodeKind
        if isUSBController(dictionary) {
            kind = .controller
        } else if storageDetected {
            kind = .storage
        } else {
            kind = inferKind(name: name, properties: properties, level: level)
        }

        return USBNode(
            id: stableID(
                name: name,
                serial: serial,
                locationID: locationID,
                vendorID: vendorID,
                productID: productID,
                path: path
            ),
            name: name,
            vendor: vendor,
            productID: productID,
            vendorID: vendorID,
            serial: serial,
            locationID: locationID,
            usbVersion: usbVersion,
            speed: speed,
            currentRequiredMA: currentRequired,
            currentAvailableMA: nil,
            extraOperatingCurrentMA: nil,
            busPowerMA: nil,
            powerWattsOverride: nil,
            level: level,
            kind: kind,
            properties: properties,
            children: relevantChildren
        )
    }

    private static func parseUSBTypeCPowerNodes(_ object: Any) -> [USBNode] {
        guard let ports = object as? [[String: Any]] else { return [] }
        return ports.enumerated().compactMap { index, port in
            guard firstBool(port, keys: ["ConnectionActive"]) == true,
                  hasPowerDeliverySource(port)
            else {
                return nil
            }

            let portNumber = firstString(port, keys: ["PortNumber", "ParentPortNumber"]) ?? "\(index + 1)"
            let powerSource = firstMatchingDescendant(port) { descendant in
                guard objectClass(descendant) == "IOPortFeaturePowerSource" else { return false }
                return descendant["WinningPowerSourceOption"] is [String: Any]
                    || (firstString(descendant, keys: ["IORegistryEntryName"])?.contains("[*]") == true)
            }

            let winningOption = powerSource?["WinningPowerSourceOption"] as? [String: Any]
            let maxPowerMW = firstNumber(winningOption ?? [:], keys: ["Max Power (mW)"])
            let maxCurrentMA = firstNumber(winningOption ?? [:], keys: ["Max Current (mA)"])
            let voltageMV = firstNumber(winningOption ?? [:], keys: ["Voltage (mV)"])
            let cableType = firstCableTypeDescription(port) ?? "Charging cable"
            let powerSourceName = firstString(powerSource ?? [:], keys: ["PowerSourceName", "IORegistryEntryName"]) ?? "USB-PD"
            let transports = firstString(port, keys: ["TransportsActive"]) ?? "CC"
            let wattText = maxPowerMW.map { USBFormatters.watts($0 / 1000.0) } ?? "Power In"

            let properties = [
                USBProperty(key: "Port", value: "USB-C \(portNumber)"),
                USBProperty(key: "Connection", value: "Active"),
                USBProperty(key: "Cable", value: cableType),
                USBProperty(key: "Power Source", value: powerSourceName.replacingOccurrences(of: " [*]", with: "")),
                USBProperty(key: "Negotiated Power", value: wattText),
                USBProperty(key: "Voltage", value: voltageMV.map { "\(Int($0)) mV" } ?? "Unknown"),
                USBProperty(key: "Current", value: maxCurrentMA.map { "\(Int($0)) mA" } ?? "Unknown"),
                USBProperty(key: "Transports", value: transports)
            ]

            return USBNode(
                id: "power.usb-c.\(portNumber)",
                name: "USB-C Charging Cable",
                vendor: powerSourceName.replacingOccurrences(of: " [*]", with: ""),
                productID: nil,
                vendorID: nil,
                serial: firstString(port, keys: ["ConnectionUUID"]),
                locationID: "Port \(portNumber)",
                usbVersion: "USB-C PD",
                speed: nil,
                currentRequiredMA: maxCurrentMA,
                currentAvailableMA: nil,
                extraOperatingCurrentMA: nil,
                busPowerMA: nil,
                powerWattsOverride: maxPowerMW.map { $0 / 1000.0 },
                level: 1,
                kind: .power,
                properties: properties,
                children: []
            )
        }
    }

    private static func parseUSBTypeCPorts(_ object: Any, usbRoots: [USBNode]) -> [USBTypeCPort] {
        guard let ports = object as? [[String: Any]] else { return [] }
        let usbNodes = usbRoots.flatMap { $0.flattened() }

        return ports.enumerated().map { index, port in
            let portNumber = firstString(port, keys: ["PortNumber", "ParentPortNumber"]) ?? "\(index + 1)"
            let isConnected = firstBool(port, keys: ["ConnectionActive"]) ?? false
            let transports = firstString(port, keys: ["TransportsActive"])
            let usbConnect = firstString(port, keys: ["IOAccessoryUSBConnectString"])

            let dataTransport = firstMatchingDescendant(port) { descendant in
                objectClass(descendant).hasPrefix("IOPortTransportStateUSB")
                    && firstString(descendant, keys: ["DataRateDescription"]) != nil
                    && firstString(descendant, keys: ["DataRateDescription"]) != "None"
            }
            let dataRate = dataTransport.flatMap { firstString($0, keys: ["DataRateDescription"]) }
            let serial = dataTransport.flatMap { firstString($0, keys: ["Serial Number", "USB Serial Number"]) }
                ?? firstString(port, keys: ["ConnectionUUID"])
            let matchedNode = serial.flatMap { serial in
                usbNodes.first { $0.serial == serial }
            }

            let powerSource = firstMatchingDescendant(port) { descendant in
                objectClass(descendant) == "IOPortFeaturePowerSource"
                    && descendant["WinningPowerSourceOption"] is [String: Any]
            }
            let winningOption = powerSource?["WinningPowerSourceOption"] as? [String: Any]
            let maxPowerMW = firstNumber(winningOption ?? [:], keys: ["Max Power (mW)"])
            let maxCurrentMA = firstNumber(winningOption ?? [:], keys: ["Max Current (mA)"])
            let voltageMV = firstNumber(winningOption ?? [:], keys: ["Voltage (mV)"])
            let cableType = firstCableTypeDescription(port)
            let hasPower = maxPowerMW != nil || powerSource != nil

            let deviceName: String
            if let matchedNode {
                deviceName = matchedNode.name
            } else if hasPower {
                deviceName = "USB-C Charging Cable"
            } else if isConnected {
                deviceName = "USB-C Connection"
            } else {
                deviceName = "No devices connected"
            }

            let detailParts = [
                cableType,
                usbConnect == "Device" ? "USB Device" : nil,
                transports
            ].compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }

            let properties = [
                USBProperty(key: "Connection", value: isConnected ? "Active" : "No devices connected"),
                USBProperty(key: "Transports", value: transports ?? "—"),
                USBProperty(key: "USB Speed", value: dataRate ?? "—"),
                USBProperty(key: "Negotiated Power", value: maxPowerMW.map { USBFormatters.watts($0 / 1000.0) } ?? "—"),
                USBProperty(key: "Current", value: maxCurrentMA.map { "\(Int($0)) mA" } ?? "—"),
                USBProperty(key: "Voltage", value: voltageMV.map { "\(Int($0)) mV" } ?? "—")
            ]

            return USBTypeCPort(
                id: "usb-c.\(portNumber)",
                portNumber: portNumber,
                isConnected: isConnected,
                deviceName: deviceName,
                detail: detailParts.joined(separator: " · "),
                transports: transports,
                dataRate: dataRate,
                powerWatts: maxPowerMW.map { $0 / 1000.0 },
                voltageMV: voltageMV,
                currentMA: maxCurrentMA,
                serial: serial,
                properties: properties
            )
        }
    }

    private static func parseThunderboltPorts(_ dictionary: [String: Any], busIndex: Int) -> [ThunderboltPort] {
        let busName = firstString(dictionary, keys: ["device_name_key", "_name"]) ?? "Thunderbolt / USB4"
        let vendor = firstString(dictionary, keys: ["vendor_name_key", "vendor_name"])
        let route = firstString(dictionary, keys: ["route_string_key"])

        return dictionary.keys.sorted().compactMap { key in
            guard key.hasPrefix("receptacle_"),
                  let receptacle = dictionary[key] as? [String: Any]
            else {
                return nil
            }

            let portNumber = firstString(receptacle, keys: ["receptacle_id_key"]) ?? key.replacingOccurrences(of: "receptacle_", with: "")
            let speed = firstString(receptacle, keys: ["current_speed_key"])
            let rawStatus = firstString(receptacle, keys: ["receptacle_status_key", "link_status_key"]) ?? "Unknown"
            let status = readableThunderboltStatus(rawStatus)
            let properties = rawProperties(from: receptacle)

            return ThunderboltPort(
                id: "tb.\(busIndex).\(portNumber)",
                busName: busName,
                deviceName: firstString(dictionary, keys: ["_name"]) ?? "USB4 Bus \(busIndex + 1)",
                vendorName: vendor,
                portNumber: portNumber,
                speed: speed,
                status: status,
                route: route,
                properties: properties
            )
        }
    }

    private static func parseExternalVolumes(_ object: Any?) -> [USBVolume] {
        guard let root = object as? [String: Any],
              let disks = root["AllDisksAndPartitions"] as? [[String: Any]]
        else {
            return []
        }

        var volumes: [USBVolume] = []
        for disk in disks {
            guard let parentIdentifier = firstString(disk, keys: ["DeviceIdentifier"]) else { continue }
            let parentInfo = diskInfo(parentIdentifier) ?? disk
            let parentMediaName = firstString(parentInfo, keys: ["MediaName", "IORegistryEntryName", "VolumeName"])
            let parentBus = firstString(parentInfo, keys: ["BusProtocol"])

            let partitions = disk["Partitions"] as? [[String: Any]] ?? []
            for partition in partitions {
                guard let identifier = firstString(partition, keys: ["DeviceIdentifier"]) else { continue }
                let info = diskInfo(identifier) ?? partition
                let busProtocol = firstString(info, keys: ["BusProtocol"]) ?? parentBus
                guard busProtocol?.localizedCaseInsensitiveContains("USB") == true else { continue }

                let name = firstString(info, keys: ["VolumeName", "MediaName", "IORegistryEntryName"])
                    ?? firstString(partition, keys: ["VolumeName", "Content"])
                    ?? identifier
                let mountPoint = firstString(info, keys: ["MountPoint"])
                guard mountPoint?.isEmpty == false else { continue }
                let writableVolume = firstBool(info, keys: ["WritableVolume", "Writable"])
                let explicitReadOnly = firstBool(info, keys: ["ReadOnlyVolume", "ReadOnly"])
                let readOnly = explicitReadOnly ?? writableVolume.map { !$0 }

                volumes.append(
                    USBVolume(
                        id: identifier,
                        name: name,
                        deviceIdentifier: identifier,
                        parentDiskIdentifier: firstString(info, keys: ["ParentWholeDisk"]) ?? parentIdentifier,
                        parentDiskMediaName: parentMediaName,
                        mountPoint: mountPoint,
                        fileSystem: firstString(info, keys: ["FilesystemUserVisibleName", "FilesystemName", "FilesystemType", "Content"]),
                        sizeBytes: firstInt64(info, keys: ["VolumeSize", "TotalSize", "Size"]),
                        freeBytes: firstInt64(info, keys: ["FreeSpace"]),
                        encrypted: firstBool(info, keys: ["Encrypted", "CoreStorageEncrypted"]) ?? false,
                        readOnly: readOnly,
                        writable: writableVolume,
                        busProtocol: busProtocol,
                        deviceTreePath: firstString(info, keys: ["DeviceTreePath"])
                    )
                )
            }
        }
        return volumes
    }

    private static func diskInfo(_ identifier: String) -> [String: Any]? {
        guard let xml = try? run("/usr/sbin/diskutil", arguments: ["info", "-plist", identifier]),
              let object = try? decodePlist(xml),
              let dictionary = object as? [String: Any]
        else {
            return nil
        }
        return dictionary
    }

    private static func rawProperties(from dictionary: [String: Any]) -> [USBProperty] {
        dictionary.keys
            .filter { key in
                key != "_items" && !(dictionary[key] is [String: Any]) && !(dictionary[key] is [[String: Any]])
            }
            .sorted { preferredOrder($0) < preferredOrder($1) }
            .compactMap { key in
                guard let value = stringify(dictionary[key]) else { return nil }
                return USBProperty(key: readableKey(key), value: value)
            }
    }

    private static func preferredOrder(_ key: String) -> String {
        let preferred = [
            "_name": "00",
            "manufacturer": "01",
            "vendor_name": "02",
            "serial_num": "03",
            "vendor_id": "04",
            "product_id": "05",
            "location_id": "06",
            "speed": "07",
            "bcd_device": "08",
            "current_required": "09",
            "current_available": "10"
        ]
        return "\(preferred[key] ?? "99")-\(key)"
    }

    private static func firstString(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = dictionary[key] else { continue }
            if let string = stringify(value), !string.isEmpty {
                return string
            }
        }
        return nil
    }

    private static func firstNumber(_ dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = dictionary[key] else { continue }
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            guard let string = stringify(value) else { continue }
            if let parsed = parseNumber(from: string) {
                return parsed
            }
        }
        return nil
    }

    private static func firstInt64(_ dictionary: [String: Any], keys: [String]) -> Int64? {
        for key in keys {
            guard let value = dictionary[key] else { continue }
            if let number = value as? NSNumber {
                return number.int64Value
            }
            guard let string = stringify(value) else { continue }
            if let parsed = parseNumber(from: string) {
                return Int64(parsed)
            }
        }
        return nil
    }

    private static func firstBool(_ dictionary: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            guard let value = dictionary[key] else { continue }
            if let bool = value as? Bool {
                return bool
            }
            if let number = value as? NSNumber {
                return number.boolValue
            }
            if let string = stringify(value) {
                if string == "Yes" || string == "TRUE" || string == "true" {
                    return true
                }
                if string == "No" || string == "FALSE" || string == "false" {
                    return false
                }
            }
        }
        return nil
    }

    private static func stringify(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            number.stringValue
        case let bool as Bool:
            bool ? "Yes" : "No"
        case let data as Data:
            data.map { String(format: "%02x", $0) }.joined()
        case let array as [Any]:
            array.compactMap { stringify($0) }.joined(separator: ", ")
        default:
            nil
        }
    }

    private static func parseNumber(from string: String) -> Double? {
        let pattern = #"[-+]?[0-9]*\.?[0-9]+"#
        guard let range = string.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return Double(string[range])
    }

    private static func objectClass(_ dictionary: [String: Any]) -> String {
        firstString(dictionary, keys: ["IOObjectClass", "IOClass"]) ?? ""
    }

    private static func isUSBController(_ dictionary: [String: Any]) -> Bool {
        let className = objectClass(dictionary)
        let name = firstString(dictionary, keys: ["IORegistryEntryName", "Description"]) ?? ""
        return className.contains("USBXHCI") || name.contains("USBXHCI")
    }

    private static func isUSBDevice(_ dictionary: [String: Any]) -> Bool {
        objectClass(dictionary) == "IOUSBHostDevice"
    }

    private static func speedDescription(from dictionary: [String: Any]) -> String? {
        if let string = firstString(dictionary, keys: ["DataRateDescription", "speed", "USB Speed"]) {
            return string
        }
        if let linkSpeed = firstNumber(dictionary, keys: ["UsbLinkSpeed"]), linkSpeed > 0 {
            if linkSpeed >= 1_000_000_000 {
                return String(format: "USB @ %.0f Gb/s", linkSpeed / 1_000_000_000.0)
            }
            if linkSpeed >= 1_000_000 {
                return String(format: "USB @ %.0f Mb/s", linkSpeed / 1_000_000.0)
            }
        }
        let usbSpeed = Int(firstNumber(dictionary, keys: ["USBSpeed", "Device Speed"]) ?? -1)
        switch usbSpeed {
        case 4: return "USB 3.x @ 5 Gb/s"
        case 3: return "USB 2.0 @ 480 Mb/s"
        case 2: return "USB 1.1 @ 12 Mb/s"
        case 1: return "USB 1.0 @ 1.5 Mb/s"
        default: return nil
        }
    }

    private static func usbVersionDescription(from dictionary: [String: Any]) -> String? {
        if let explicit = firstString(dictionary, keys: ["usb_version", "USB Version"]) {
            return explicit
        }
        guard let bcdUSB = firstNumber(dictionary, keys: ["bcdUSB", "bcd_device"]) else {
            return nil
        }
        let value = Int(bcdUSB)
        if value == 800 {
            return "USB 3.2"
        }
        if value == 512 {
            return "USB 2.0"
        }
        return "USB \(value)"
    }

    private static func hasPowerDeliverySource(_ dictionary: [String: Any]) -> Bool {
        firstMatchingDescendant(dictionary) { descendant in
            objectClass(descendant) == "IOPortFeaturePowerSource"
                && descendant["WinningPowerSourceOption"] is [String: Any]
        } != nil
    }

    private static func firstCableTypeDescription(_ dictionary: [String: Any]) -> String? {
        firstMatchingDescendant(dictionary) { descendant in
            firstString(descendant, keys: ["Product Type Description"]) != nil
        }.flatMap { firstString($0, keys: ["Product Type Description"]) }
    }

    private static func firstMatchingDescendant(
        _ dictionary: [String: Any],
        where matches: ([String: Any]) -> Bool
    ) -> [String: Any]? {
        if matches(dictionary) {
            return dictionary
        }
        let children = dictionary["IORegistryEntryChildren"] as? [[String: Any]] ?? []
        for child in children {
            if let match = firstMatchingDescendant(child, where: matches) {
                return match
            }
        }
        return nil
    }

    private static func containsRecursive(_ value: Any, needles: [String]) -> Bool {
        if let dictionary = value as? [String: Any] {
            return dictionary.contains { key, child in
                needles.contains { key.localizedCaseInsensitiveContains($0) }
                    || containsRecursive(child, needles: needles)
            }
        }
        if let array = value as? [Any] {
            return array.contains { containsRecursive($0, needles: needles) }
        }
        guard let string = stringify(value) else {
            return false
        }
        return needles.contains { string.localizedCaseInsensitiveContains($0) }
    }

    private static func stableID(
        name: String,
        serial: String?,
        locationID: String?,
        vendorID: String?,
        productID: String?,
        path: String
    ) -> String {
        let parts = [serial, locationID, vendorID, productID, name, path].compactMap { value in
            value?.lowercased().replacingOccurrences(of: " ", with: "-")
        }
        return parts.joined(separator: ".")
    }

    private static func inferKind(name: String, properties: [USBProperty], level: Int) -> USBNodeKind {
        let haystack = ([name] + properties.flatMap { [$0.key, $0.value] })
            .joined(separator: " ")
            .lowercased()

        if level == 0 || haystack.contains("host controller") || haystack.contains("xhci") {
            return .controller
        }
        if haystack.contains("hub") {
            return .hub
        }
        if haystack.contains("storage") || haystack.contains("disk") || haystack.contains("mass") || haystack.contains("ssd") || haystack.contains("flash") {
            return .storage
        }
        if haystack.contains("display") || haystack.contains("monitor") {
            return .display
        }
        if haystack.contains("ipad") || haystack.contains("iphone") || haystack.contains("phone") {
            return .mobile
        }
        if haystack.contains("keyboard") || haystack.contains("mouse") || haystack.contains("receiver") || haystack.contains("hid") {
            return .input
        }
        if haystack.contains("audio") || haystack.contains("speaker") || haystack.contains("microphone") {
            return .audio
        }
        if haystack.contains("ethernet") || haystack.contains("network") || haystack.contains("lan") {
            return .network
        }
        if haystack.contains("power") || haystack.contains("charging") || haystack.contains("usb-pd") {
            return .power
        }
        return .device
    }

    private static func readableKey(_ key: String) -> String {
        key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: " key", with: "")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func readableThunderboltStatus(_ status: String) -> String {
        status
            .replacingOccurrences(of: "receptacle_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
