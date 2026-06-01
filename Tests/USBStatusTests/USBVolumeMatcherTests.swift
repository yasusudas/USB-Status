import Testing
@testable import USBStatus

struct USBVolumeMatcherTests {
    @Test
    func matchesSameHardwareNamesByIORegistryLocation() {
        let firstDevice = storageDevice(
            serial: "0101b4d88bb7",
            locationID: "2097152",
            registryLocation: "00200000"
        )
        let secondDevice = storageDevice(
            serial: "00016207071624104228",
            locationID: "18874368",
            registryLocation: "01200000"
        )
        let volumes = [
            volume(
                name: "USBめもりぃ",
                identifier: "disk4s1",
                path: "IODeviceTree:/arm-io/usb-drd1@2280000/usb-drd1-port-ss@01200000"
            ),
            volume(
                name: "SCHOOLDOCS",
                identifier: "disk5s2",
                path: "IODeviceTree:/arm-io/usb-drd0@2280000/usb-drd0-port-ss@00200000"
            )
        ]

        #expect(USBVolumeMatcher.matchedVolumes(
            for: firstDevice,
            in: volumes,
            allStorageDevices: [firstDevice, secondDevice]
        ).map(\.name) == ["SCHOOLDOCS"])

        #expect(USBVolumeMatcher.matchedVolumes(
            for: secondDevice,
            in: volumes,
            allStorageDevices: [firstDevice, secondDevice]
        ).map(\.name) == ["USBめもりぃ"])
    }

    @Test
    func doesNotGuessWhenMultipleSameMediaNamesHaveNoLocationSignal() {
        let firstDevice = storageDevice(serial: "A", locationID: nil, registryLocation: nil)
        let secondDevice = storageDevice(serial: "B", locationID: nil, registryLocation: nil)
        let volumes = [
            volume(name: "ONE", identifier: "disk4s1", path: nil),
            volume(name: "TWO", identifier: "disk5s1", path: nil)
        ]

        #expect(USBVolumeMatcher.matchedVolumes(
            for: firstDevice,
            in: volumes,
            allStorageDevices: [firstDevice, secondDevice]
        ).isEmpty)
    }

    private func storageDevice(serial: String, locationID: String?, registryLocation: String?) -> USBNode {
        USBNode(
            id: serial,
            name: "SanDisk 3.2Gen1",
            vendor: "USB",
            productID: "21931",
            vendorID: "1921",
            serial: serial,
            locationID: locationID,
            usbVersion: "USB 3.2",
            speed: "USB @ 5 Gb/s",
            currentRequiredMA: 900,
            currentAvailableMA: nil,
            extraOperatingCurrentMA: nil,
            busPowerMA: nil,
            powerWattsOverride: nil,
            level: 1,
            kind: .storage,
            properties: registryLocation.map { [USBProperty(key: "IORegistryEntryLocation", value: $0)] } ?? [],
            children: []
        )
    }

    private func volume(name: String, identifier: String, path: String?) -> USBVolume {
        USBVolume(
            id: identifier,
            name: name,
            deviceIdentifier: identifier,
            parentDiskIdentifier: String(identifier.prefix(5)),
            parentDiskMediaName: "SanDisk 3.2Gen1",
            mountPoint: "/Volumes/\(name)",
            fileSystem: "ExFAT",
            sizeBytes: 1_000_000,
            freeBytes: 500_000,
            encrypted: false,
            readOnly: false,
            writable: true,
            busProtocol: "USB",
            deviceTreePath: path
        )
    }
}
