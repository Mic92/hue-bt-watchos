import CoreBluetooth

class Bulb: Identifiable {
    let peripheral: CBPeripheral
    var lightCharacteristic: CBCharacteristic?;
    var brightnessCharacteristic: CBCharacteristic?;
    var nameCharacteristic: CBCharacteristic?;
    @Published var name: String?;
    let id: UUID;
    @Published var lightOn = false
    @Published var brigthness = 0
    
    init(_ p: CBPeripheral) {
        self.peripheral = p
        self.id = p.identifier
    }
}

class BleManager: NSObject, ObservableObject {
    var centralManager: CBCentralManager!
    @Published var bulbs = [Bulb]()
    @Published var status = "startup..."

    static let LightService = CBUUID(string: "932c32bd-0000-47a2-835a-a8d455b859dd")
    static let NameService = CBUUID(string: "0000fe0f-0000-1000-8000-00805f9b34fb")
    static let LightCharacteristic = CBUUID(string: "932c32bd-0002-47a2-835a-a8d455b859dd")
    static let BrightnessCharacteristic = CBUUID(string: "932c32bd-0003-47a2-835a-a8d455b859dd")
    static let ColorCharacteristic = CBUUID(string: "932c32bd-0005-47a2-835a-a8d455b859dd")
    static let NameCharacteristic = CBUUID(string: "97fe6561-0003-4f62-86e9-b71ee2da3d22")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    func scan() {
        status = "scanning..."
        centralManager.scanForPeripherals(withServices: [BleManager.NameService], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true as Bool)])
    }
    
    func cleanup(_ peripheral: CBPeripheral) {
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
        print("discovered \(peripheral.identifier)")
        for bulb in bulbs {
            if bulb.peripheral.identifier == peripheral.identifier {
                return
            }
        }
        bulbs.append(Bulb(peripheral))
        central.connect(peripheral, options: [:])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error { print(error.localizedDescription) }
        cleanup(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "connected"
        central.stopScan()
        peripheral.delegate = self
        peripheral.discoverServices([BleManager.LightService, BleManager.NameService])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cleanup(peripheral)
    }
}

extension BleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Got error when discovering services: \(error.localizedDescription)")
            cleanup(peripheral)
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            print("discovered service \(service.uuid)")
            if (service.uuid == BleManager.NameService) {
                status = "discovered name service"
                peripheral.discoverCharacteristics([BleManager.NameCharacteristic], for: service)
            } else if (service.uuid == BleManager.LightService) {
                status = "discovered light service"
                peripheral.discoverCharacteristics([BleManager.LightCharacteristic, BleManager.BrightnessCharacteristic], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Got error when discovering characteristics: \(error.localizedDescription)")
            cleanup(peripheral)
            return
        }
        guard let bulb = bulbs.first(where: { $0.peripheral == peripheral }) else { return }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            let name : String
            if characteristic.uuid == BleManager.LightCharacteristic {
                name = "light"
                bulb.lightCharacteristic = characteristic
                let light: [UInt8] = [0]
                peripheral.writeValue(Data(light), for: characteristic, type: CBCharacteristicWriteType.withResponse)
            } else if characteristic.uuid == BleManager.BrightnessCharacteristic {
                name = "brightness"
                bulb.brightnessCharacteristic = characteristic
            } else if characteristic.uuid == BleManager.NameCharacteristic {
                print("discovered name characteristic")
                name = "name"
                //peripheral.readValue(for: characteristic)
            } else {
                name = "unknown \(characteristic.uuid)"
            }
            print("discovered \(name) characteristic in \(service.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Got error when updating characteristics: \(error.localizedDescription)")
            return
        }
        guard let bulb = bulbs.first(where: { $0.peripheral == peripheral }) else { return }
        
        if characteristic == bulb.lightCharacteristic {
            guard let newData = characteristic.value else { return }
            bulb.lightOn = newData[0] == 0x01;
        } else if characteristic == bulb.nameCharacteristic {
            guard let newData = characteristic.value else { return }
            let name = String(data: newData, encoding: .utf8)
            print("received name \(name ?? "nothing")")
            bulb.name = name
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Got error after writing \(characteristic.uuid): \(error.localizedDescription)")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Got error after notification state: \(error.localizedDescription) for characteristic \(characteristic.uuid)")
        }
        let name: String
        if characteristic.uuid == BleManager.LightCharacteristic {
            name = "light"
        } else if characteristic.uuid == BleManager.NameCharacteristic {
            name = "name"
        } else {
            return
        }
        print("Notification \(characteristic.isNotifying ? "began" : "stop") on \(name)")
    }
    
    // Stub to stop run-time warning
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {}
}

