import CoreBluetooth


class Bulb {
    let peripheral: CBPeripheral
    var lightCharacteristic: CBCharacteristic?;
    var brightnessCharacteristic: CBCharacteristic?;
    @Published var lightOn = false
    @Published var brigthness = 0
    @Published var macAddress: String?
    
    init(_ p: CBPeripheral) {
        self.peripheral = p
    }
}

class BleManager: NSObject, ObservableObject {
    var centralManager: CBCentralManager!
    var bulbs = [Bulb]()
    @Published var status = "startup..."
    
    static let LightService = CBUUID(string: "932c32bd-0000-47a2-835a-a8d455b859dd")
    static let LightCharacteristic = CBUUID(string: "932c32bd-0002-47a2-835a-a8d455b859dd")
    static let BrightnessCharacteristic = CBUUID(string: "932c32bd-0003-47a2-835a-a8d455b859dd")
    static let ColorCharacteristic = CBUUID(string: "932c32bd-0005-47a2-835a-a8d455b859dd")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    func scan() {
        centralManager.scanForPeripherals(withServices: [BleManager.LightService], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true as Bool)])
    }
    
    func cleanup(_ peripheral: CBPeripheral) {
        /*guard discoveredPeripheral?.state != .disconnected,
         let services = discoveredPeripheral?.services else {
         centralManager.cancelPeripheralConnection(discoveredPeripheral!)
         return
         }
         for service in services {
         if let characteristics = service.characteristics {
         for characteristic in characteristics {
         if characteristic.uuid.isEqual(BleManager.LightCharacteristic) {
         if characteristic.isNotifying {
         discoveredPeripheral?.setNotifyValue(false, for: characteristic)
         return
         }
         
         }
         }
         }
         }*/
        bulbs.removeFirst(bulbs.firstIndex(where: { $0.peripheral == peripheral })!);
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

extension BleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: scan()
        case .poweredOff, .resetting:
            for bulb in bulbs {
                cleanup(bulb.peripheral)
            }
        default: return
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        status = "discovered peripheral"
        bulbs.append(Bulb(peripheral))
        central.connect(peripheral, options: [:])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error { print(error.localizedDescription) }
        cleanup(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "connected to peripheral"
        central.stopScan()
        peripheral.delegate = self
        peripheral.discoverServices([BleManager.LightService])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cleanup(peripheral)
    }
}

extension BleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            cleanup(peripheral)
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            status = "discovered service"
            peripheral.discoverCharacteristics([BleManager.LightCharacteristic, BleManager.BrightnessCharacteristic], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            cleanup(peripheral)
            return
        }
        guard let bulb = bulbs.first(where: { $0.peripheral == peripheral }) else { return }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == BleManager.LightCharacteristic {
                status = "discovered LightCharacteristic"
                bulb.lightCharacteristic = characteristic
            } else if characteristic.uuid == BleManager.BrightnessCharacteristic {
                status = "discovered BrightnessCharacteristic"
                bulb.brightnessCharacteristic = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        guard let bulb = bulbs.first(where: { $0.peripheral == peripheral }) else { return }
        
        if characteristic == bulb.lightCharacteristic {
            guard let newData = characteristic.value else { return }
            let stringFromData = String(data: newData, encoding: .utf8)
            print("received \(stringFromData ?? "nothing")")
            bulb.lightOn = newData[0] == 0x01;
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { print(error.localizedDescription) }
        guard characteristic.uuid == BleManager.LightCharacteristic else { return }
        if characteristic.isNotifying {
            print("Notification began on \(characteristic)")
        } else {
            print("Notification stopped on \(characteristic). Disconnecting...")
        }
    }
    
    // Stub to stop run-time warning
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {}
}

