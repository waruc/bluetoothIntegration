import UIKit
import CoreBluetooth

extension String {
    func hexadecimal() -> Data? {
        var data = Data(capacity: characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, characters.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        
        guard data.count > 0 else {
            return nil
        }
        
        return data
    }
}


//let speedNotificationKey = "speed"
//
//class FirstViewController: UIViewController {
//    @IBOutlet weak var sentNotificationLabel: UILabel!
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        NotificationCenter.default.addObserver(self, selector: #selector(updateNotificationSentLabel), name: NSNotification.Name(rawValue: mySpecialNotificationKey), object: nil)
//    }
//    
//    // 2. Post notification using "special notification key"
//    func notify() {
//        NotificationCenter.default.post(name: Notification.Name(rawValue: mySpecialNotificationKey), object: self)
//    }
//    
//    func updateNotificationSentLabel() {
//        self.sentNotificationLabel.text = "Notification sent!"
//    }
//}

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
    
    var timer = Timer()
    let speedUpdateInterval:TimeInterval = 1.0 // Number of seconds between speed requests
    
//    let newValueNotification = Notification.Name("NewValue")
    
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
    
    func pauseScan() {
        print("*** Pausing Scanning ***")
        _ = Timer(timeInterval: timerPauseInterval, target: self, selector: #selector(resumeScan), userInfo: nil, repeats: false)
        centralManager.stopScan()
    }
    
    func resumeScan() {
        if keepScanning {
            print("*** Resuming Scanning ***")
            _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            
        }
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
        
        if (service.uuid.uuidString == "FFE0" && service.characteristics![0].uuid.uuidString == "FFE1") {
            // Found OBD-II input/output service & characteristic
            monitorMetric(metricCmd: "010D\n\r", bleServiceCharacteristic: service.characteristics![0])
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("ERROR ON UPDATING VALUE FOR CHARACTERISTIC: \(characteristic) - \(String(describing: error?.localizedDescription))")
            return
        }
        
        var metric:Int?
        var returnedBytes = [UInt8](characteristic.value!)
        if (returnedBytes.count == 7) {
            metric = Int("\(String(UnicodeScalar(returnedBytes[returnedBytes.count - 3])))\(String(UnicodeScalar(returnedBytes[returnedBytes.count - 2])))", radix:16)
        }
        
        if (metric != nil) {
            print("\n\n Current speed: \(metric!) kph\n\n")
        }
        
//        NotificationCenter.default.post(name: newValueNotification, object: ["value": metric!])
    }
    
    func monitorMetric(metricCmd: String, bleServiceCharacteristic: CBCharacteristic) {
        timer = Timer.scheduledTimer(timeInterval: speedUpdateInterval,
                                     target: self,
                                     selector: #selector(monitorMetricRequest),
                                     userInfo: ["cmd": metricCmd, "bleServiceCharacteristic": bleServiceCharacteristic],
                                     repeats: true)
    }
    
    func monitorMetricRequest(timer: Timer) {
        let userInfoDict = timer.userInfo as! Dictionary<String, Any>
        requestMetric(cmd: userInfoDict["cmd"] as! String, bleServiceCharacteristic: userInfoDict["bleServiceCharacteristic"] as! CBCharacteristic)
    }
    
    func requestMetric(cmd: String, bleServiceCharacteristic: CBCharacteristic) {
        let cmdBytes = cmd.hexadecimal()!
        obd2?.setNotifyValue(true, for: bleServiceCharacteristic)
        obd2?.writeValue(cmdBytes, for: bleServiceCharacteristic, type: .withResponse)
        
//        NotificationCenter.default.addObserver(self, selector: #selector(getNewValue), name: newValueNotification, object: nil)
    }
    
}

