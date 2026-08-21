import Foundation
import IOKit.hid

final class DJIButtonMonitor {
    enum Mode {
        case active(DeviceIdentity, suppressOriginal: Bool)
        case learning
    }

    enum MonitorError: LocalizedError {
        case couldNotOpen(Int32)

        var errorDescription: String? {
            switch self {
            case let .couldNotOpen(code):
                "Could not open the receiver (I/O error \(code)). Check Input Monitoring permission."
            }
        }
    }

    var onConnectionChanged: ((Bool, DeviceIdentity?) -> Void)?
    var onButtonPress: ((DeviceIdentity) -> Void)?
    var onError: ((String) -> Void)?

    private var manager: IOHIDManager?
    private var mode: Mode?

    deinit {
        stop()
    }

    func start(mode: Mode) {
        stop()
        self.mode = mode

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        var matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: 0x0C,
        ]
        if case let .active(device, _) = mode {
            matching[kIOHIDVendorIDKey as String] = device.vendorID
            matching[kIOHIDProductIDKey as String] = device.productID
        }
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DJIButtonMonitor>.fromOpaque(context).takeUnretainedValue()
                .deviceMatched(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<DJIButtonMonitor>.fromOpaque(context).takeUnretainedValue()
                .deviceRemoved(device)
        }, context)
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            Unmanaged<DJIButtonMonitor>.fromOpaque(context).takeUnretainedValue()
                .received(value)
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let options: IOOptionBits
        if case let .active(_, suppressOriginal) = mode, suppressOriginal {
            options = IOOptionBits(kIOHIDOptionsTypeSeizeDevice)
        } else {
            options = IOOptionBits(kIOHIDOptionsTypeNone)
        }

        let result = IOHIDManagerOpen(manager, options)
        guard result == kIOReturnSuccess else {
            onError?(MonitorError.couldNotOpen(result).localizedDescription)
            if options == IOOptionBits(kIOHIDOptionsTypeSeizeDevice) {
                let fallback = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
                if fallback != kIOReturnSuccess {
                    stop()
                }
            } else {
                stop()
            }
            return
        }
    }

    func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        mode = nil
        onConnectionChanged?(false, nil)
    }

    private func deviceMatched(_ device: IOHIDDevice) {
        let identity = identity(for: device)
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChanged?(true, identity)
        }
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        let identity = identity(for: device)
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionChanged?(false, identity)
        }
    }

    private func received(_ value: IOHIDValue) {
        guard IOHIDValueGetIntegerValue(value) != 0 else { return }
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)

        // Consumer-page volume up/down are the shutter signals emitted by the receiver.
        guard usagePage == 0x0C, usage == 0xE9 || usage == 0xEA else { return }
        let device = IOHIDElementGetDevice(element)
        let identity = identity(for: device)
        DispatchQueue.main.async { [weak self] in
            self?.onButtonPress?(identity)
        }
    }

    private func identity(for device: IOHIDDevice) -> DeviceIdentity {
        DeviceIdentity(
            vendorID: integerProperty(kIOHIDVendorIDKey, from: device),
            productID: integerProperty(kIOHIDProductIDKey, from: device),
            productName: stringProperty(kIOHIDProductKey, from: device) ?? "Consumer device"
        )
    }

    private func integerProperty(_ key: String, from device: IOHIDDevice) -> Int {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return 0 }
        if CFGetTypeID(value) == CFNumberGetTypeID() {
            return (value as! NSNumber).intValue
        }
        return 0
    }

    private func stringProperty(_ key: String, from device: IOHIDDevice) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }
}
