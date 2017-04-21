//
//  ViewController.swift
//  Connecting Bluetooth Low Energy
//
//  Created by ishansaksena on 4/16/17.
//  Copyright © 2017 ishansaksena. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Outlets
    // Labels
    
    // Bluetooth references
    var centralManager: CBCentralManager!
    var obd2: CBPeripheral?
    var speedCharacteristic:CBCharacteristic?
    var peripherals = [CBPeripheral]()
    var keepScanning = false
    
    // OBD2 Device Specific variables
    let obd2TagName = "OBDBLE"
    let obd2UUID = CBUUID(string: "DDEAF648-037B-46F4-9706-72DF00D8C8C3")
    
    // Scanning interval times
    let timerPauseInterval:TimeInterval = 10.0
    let timerScanInterval:TimeInterval = 2.0
    
    // MARK: - ViewController Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - CBCentralManagerDelegate methods
    // Invoked when the central manager’s state is updated.
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
            _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            
            // Initiate Scan for Peripherals
            //Option 1: Scan for all devices
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            
            // TODO: FIND THE UUID FOR THE SERVICE WE ARE INTERESTED IN
            // Option 2: Scan for devices that have the service you're interested in...
            //let sensorTagAdvertisingUUID = CBUUID(string: Device.SensorTagAdvertisingUUID)
            //print("Scanning for SensorTag adverstising with UUID: \(obd2UUID)")
            //centralManager.scanForPeripherals(withServices: [obd2UUID], options: nil)
        }
    }
    
    /*
     Invoked when the central manager discovers a peripheral while scanning.
     
     The advertisement data can be accessed through the keys listed in Advertisement Data Retrieval Keys.
     You must retain a local copy of the peripheral if any command is to be performed on it.
     In use cases where it makes sense for your app to automatically connect to a peripheral that is
     located within a certain range, you can use RSSI data to determine the proximity of a discovered
     peripheral device.
     
     central - The central manager providing the update.
     peripheral - The discovered peripheral.
     advertisementData - A dictionary containing any advertisement data.
     RSSI - The current received signal strength indicator (RSSI) of the peripheral, in decibels.
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("centralManager didDiscoverPeripheral - CBAdvertisementDataLocalNameKey is \"\(CBAdvertisementDataLocalNameKey)\"")
        
        if let data = advertisementData["kCBAdvDataLocalName"] {
            print("The \(CBAdvertisementDataLocalNameKey) is \(data).")
        }
        
        print("RSSI: \(RSSI)")
        
        // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
        if let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print("NEXT PERIPHERAL NAME: \(peripheralName)")
            print("NEXT PERIPHERAL UUID: \(peripheral.identifier.uuidString)")
            
            if peripheralName == obd2TagName {
                print("*** FOUND OBDBLE! Attempting to connect now! ***")
                // to save power, stop scanning for other devices
                // keepScanning = false
                
                // save a reference to the sensor tag
                self.obd2 = peripheral
                self.obd2!.delegate = self
                // Must persist obd2 objects to listen for didConnectPeripheral
                peripherals.append(peripheral)
                
                // Request a connection to the peripheral
                centralManager.connect(obd2!, options: nil)
            }
        }
    }
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     
     This method is invoked when a call to connectPeripheral:options: is successful.
     You typically implement this method to set the peripheral’s delegate and to discover its services.
     */
    func centralManager(central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("**** 🐔Successfully connected!🦄 ****")
        
        // Discover services now that we're connected to the OBD2
        // - NOTE:  we pass nil here to request ALL services be discovered.
        //          If there was a subset of services we were interested in, we could pass the UUIDs here.
        //          Doing so saves battery life and saves time.
        peripheral.discoverServices(nil)
    }
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.
     This method is invoked when a connection initiated via the connectPeripheral:options: method fails to complete.
     Because connection attempts do not time out, a failed connection usually indicates a transient issue,
     in which case you may attempt to connect to the peripheral again.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?){
        print("*** Failed to Connect! ***")
    }
    
    /*
     Invoked when an existing connection with a peripheral is torn down.
     
     This method is invoked when a peripheral connected via the connectPeripheral:options: method is disconnected.
     If the disconnection was not initiated by cancelPeripheralConnection:, the cause is detailed in error.
     After this method is called, no more methods are invoked on the peripheral device’s CBPeripheralDelegate object.
     
     Note that when a peripheral is disconnected, all of its services, characteristics, and characteristic descriptors are invalidated.
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("**** Disconnected from Peripheral")
        print("Peripheral name: \(String(describing: peripheral.name))")
        
        if error != nil {
            print("****** DISCONNECTION DETAILS: \(error!.localizedDescription)")
        }
        self.obd2 = nil
    }
    
    //MARK: - CBPeripheralDelegate methods
    
    /*
     Invoked when you discover the peripheral’s available services.
     
     This method is invoked when your app calls the discoverServices: method.
     If the services of the peripheral are successfully discovered, you can access them
     through the peripheral’s services property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    // When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING SERVICES: \(String(describing: error?.localizedDescription))")
            return
        }
        
        // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
        if let services = peripheral.services {
            for service in services {
                print("Discovered service \(service)")
                // If we found either the temperature or the humidity service, discover the characteristics for those services.
                //if (service.UUID == CBUUID(string: Device.TemperatureServiceUUID)) ||
                //    (service.UUID == CBUUID(string: Device.HumidityServiceUUID)) {
                peripheral.discoverCharacteristics(nil, for: service)
                //}
            }
        }
    }
    
    /*
     Invoked when you discover the characteristics of a specified service.
     
     If the characteristics of the specified service are successfully discovered, you can access
     them through the service's characteristics property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("ERROR DISCOVERING CHARACTERISTICS: \(String(describing: error?.localizedDescription))")
            return
        }
        
        if let characteristics = service.characteristics {
            var enableValue:UInt8 = 1
            let enableBytes = NSData(bytes: &enableValue, length: MemoryLayout<UInt8>.size)
            
            for characteristic in characteristics {
                // Temperature Data Characteristic
                //if characteristic.UUID == CBUUID(string: Device.TemperatureDataUUID) {
                // Enable the IR Temperature Sensor notifications
                speedCharacteristic = characteristic
                obd2?.setNotifyValue(true, for: characteristic)
                //}
                
                // Temperature Configuration Characteristic
                //if characteristic.UUID == CBUUID(string: Device.TemperatureConfig) {
                // Enable IR Temperature Sensor
                obd2?.writeValue(enableBytes as Data, for: characteristic, type: .withResponse)
                //}
            }
        }
    }
    
    /*
     Invoked when you retrieve a specified characteristic’s value,
     or when the peripheral device notifies your app that the characteristic’s value has changed.
     
     This method is invoked when your app calls the readValueForCharacteristic: method,
     or when the peripheral notifies your app that the value of the characteristic for
     which notifications and indications are enabled has changed.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    // TODO: PROCESS AND STORE INCOMING VALUES
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("ERROR ON UPDATING VALUE FOR CHARACTERISTIC: \(characteristic) - \(String(describing: error?.localizedDescription))")
            return
        }
        
        // extract the data from the characteristic's value property and display the value based on the characteristic type
        if let dataBytes = characteristic.value {
            //if characteristic.UUID == CBUUID(string: Device.TemperatureDataUUID) {
            displaySpeed(data: dataBytes)
            //}// else if characteristic.UUID == CBUUID(string: Device.HumidityDataUUID) {
            //displayHumidity(dataBytes)
            //}
        }
    }
    
    // MARK: Helper Functions
    // Scanning uses up battery on phone, so pause the scan process for the designated interval.
    func pauseScan() {
        print("*** Pausing Scanning ***")
        _ = Timer(timeInterval: timerPauseInterval, target: self, selector: #selector(resumeScan), userInfo: nil, repeats: false)
        centralManager.stopScan()
    }
    
    // Continue scanning for objects
    func resumeScan() {
        if keepScanning {
            print("*** Resuming Scanning ***")
            _ = Timer(timeInterval: timerScanInterval, target: self, selector: #selector(pauseScan), userInfo: nil, repeats: false)
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            
        }
    }
    
    func displaySpeed(data: Data) {
        print(data)
    }
}

