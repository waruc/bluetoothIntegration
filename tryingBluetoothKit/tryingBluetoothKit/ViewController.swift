import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var obd2: CBPeripheral?
    var dataCharacteristic:CBCharacteristic?
    var peripherals = [CBPeripheral]()
    var readService:CBService?
    var keepScanning = false
    
    let obd2TagName = "OBDBLE"
    let obd2UUID = CBUUID(string: "DDEAF648-037B-46F4-9706-72DF00D8C8C3")
    
    let timerPauseInterval:TimeInterval = 10.0
    let timerScanInterval:TimeInterval = 2.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //var showAlert = true
        var message = ""
        
        switch central.state {
        case .poweredOff:
            message = "Bluetooth on this device is currently powered off."
        case .unsupported:
            message = "This device does not support Bluetooth Low Energy."
        case .unauthorized:
            message = "This app is not authorized to use Bluetooth Low Energy."
        case .resetting:
            message = "The BLE Manager is resetting; a state update is pending."
        case .unknown:
            message = "The state of the BLE Manager is unknown."
        case .poweredOn:
            //showAlert = false
            message = "Bluetooth LE is turned on and ready for communication."
            
            print(message)
            
            keepScanning = true
            //_ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("NEXT PERIPHERAL NAME: \(peripheralName)")
            print("NEXT PERIPHERAL UUID: \(peripheral.identifier.uuidString)")
            
            if peripheralName == obd2TagName {
                print("*** FOUND OBDBLE! Attempting to connect now! ***")
                keepScanning = false
                
                self.obd2 = peripheral
                self.obd2!.delegate = self
                peripherals.append(peripheral)
                
                centralManager.connect(obd2!, options: nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("**** 🐔Successfully connected!🦄 ****")
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?){
        print("*** Failed to Connect! ***")
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("**** Disconnected from Peripheral")
        print("Peripheral name: \(String(describing: peripheral.name))")
        
        if error != nil {
            print("****** DISCONNECTION DETAILS: \(error!.localizedDescription)")
        }
        self.obd2 = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING SERVICES: \(String(describing: error?.localizedDescription))")
            return
        }
        
        if let services = peripheral.services {
            for service in services {
                print("Discovered service \(service)")
                if (service.uuid.uuidString == "FFE0") {
                    readService = service
                }
                
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING CHARACTERISTICS: \(String(describing: error?.localizedDescription))")
            return
        }
        
        for c in service.characteristics! {
            if c.uuid.uuidString == "FFE1" {
                var enableValue:UInt16 = 269 //'010D'
                //var enableValue:UInt8 = 13 //'0D'
                let enableBytes = NSData(bytes: &enableValue, length: MemoryLayout<UInt16>.size)
                
                //dataCharacteristic = c // Take that for data
                obd2?.setNotifyValue(true, for: c)
                //obd2?.writeValue(enableBytes as Data, for: c, type: .withoutResponse)
                //obd2?.readValue(for: c)
                obd2?.writeValue(enableBytes as Data, for: c, type: .withResponse)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("ERROR ON UPDATING VALUE FOR CHARACTERISTIC: \(characteristic) - \(String(describing: error?.localizedDescription))")
            return
        }
        
        print(characteristic)
        for b in characteristic.value! {
            print(b)
        }
        
        print(characteristic.value!.map{ String(format: "%02hhx", $0) }.joined())
        
        var currSpeed:UInt8?
        var returnedBytes = [UInt8](characteristic.value!)
        if (returnedBytes.index(of: 13) != 0) {
            currSpeed = returnedBytes[returnedBytes.count - 2]
        }
        
        if (currSpeed != nil) {
            print("\n\nThe car's current speed is \(currSpeed!) mph\n\n")
        }
    }
    
//    func pauseScan() {
//        print("*** Pausing Scanning ***")
//        _ = Timer(timeInterval: timerPauseInterval, target: self, selector: #selector(resumeScan), userInfo: nil, repeats: false)
//        centralManager.stopScan()
//    }
//    
//    func resumeScan() {
//        if keepScanning {
//            print("*** Resuming Scanning ***")
//            _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
//            centralManager.scanForPeripherals(withServices: nil, options: nil)
//        } else {
//            
//        }
//    }
    
}

