//
//  ViewController.swift
//  Beacon
//
//  Created by Troy Stribling on 4/13/15.
//  Copyright (c) 2015 Troy Stribling. The MIT License (MIT).
//

import UIKit
import CoreBluetooth
import CoreMotion
import BlueCapKit

class ViewController: UITableViewController {
    
    @IBOutlet var xAccelerationLabel        : UILabel!
    @IBOutlet var yAccelerationLabel        : UILabel!
    @IBOutlet var zAccelerationLabel        : UILabel!
    @IBOutlet var xRawAccelerationLabel     : UILabel!
    @IBOutlet var yRawAccelerationLabel     : UILabel!
    @IBOutlet var zRawAccelerationLabel     : UILabel!
    
    @IBOutlet var rawUpdatePeriodlabel      : UILabel!
    @IBOutlet var updatePeriodLabel         : UILabel!
    
    @IBOutlet var startAdvertisingSwitch    : UISwitch!
    @IBOutlet var startAdvertisingLabel     : UILabel!
    @IBOutlet var enableLabel               : UILabel!
    @IBOutlet var enabledSwitch             : UISwitch!
    
    let accelerometer                           = Accelerometer()
    
    let accelerometerService                    = MutableService(profile:ConfiguredServiceProfile<TISensorTag.AccelerometerService>())
    let accelerometerDataCharacteristic         = MutableCharacteristic(profile:RawArrayCharacteristicProfile<TISensorTag.AccelerometerService.Data>())
    let accelerometerEnabledCharacteristic      = MutableCharacteristic(profile:RawCharacteristicProfile<TISensorTag.AccelerometerService.Enabled>())
    let accelerometerUpdatePeriodCharacteristic = MutableCharacteristic(profile:RawCharacteristicProfile<TISensorTag.AccelerometerService.UpdatePeriod>())
    
    required init?(coder aDecoder:NSCoder) {
        super.init(coder:aDecoder)
        self.accelerometerService.characteristics = [self.accelerometerDataCharacteristic, self.accelerometerEnabledCharacteristic, self.accelerometerUpdatePeriodCharacteristic]
        self.respondToWriteRequests()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if self.accelerometer.accelerometerAvailable {
            self.startAdvertisingSwitch.enabled = true
            self.startAdvertisingLabel.textColor = UIColor.blackColor()
            self.enabledSwitch.enabled = true
            self.enableLabel.textColor = UIColor.blackColor()
            self.updatePeriod()
        } else {
            self.startAdvertisingSwitch.enabled = false
            self.startAdvertisingSwitch.on = false
            self.startAdvertisingLabel.textColor = UIColor.lightGrayColor()
            self.enabledSwitch.enabled = false
            self.enabledSwitch.on = false
            self.enableLabel.textColor = UIColor.lightGrayColor()
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    @IBAction func toggleEnabled(sender:AnyObject) {
        if self.accelerometer.accelerometerActive {
            self.accelerometer.stopAccelerometerUpdates()
        } else {
            let accelrometerDataFuture = self.accelerometer.startAcceleromterUpdates()
            accelrometerDataFuture.onSuccess {data in
                self.updateAccelerometerData(data)
            }
            accelrometerDataFuture.onFailure {error in
                self.presentViewController(UIAlertController.alertOnError(error), animated:true, completion:nil)
            }
        }
    }
    
    @IBAction func toggleAdvertise(sender:AnyObject) {
        let manager = PeripheralManager.sharedInstance
        if manager.isAdvertising {
            manager.stopAdvertising().onSuccess {
                self.presentViewController(UIAlertController.alertWithMessage("stoped advertising"), animated:true, completion:nil)
            }
            self.accelerometerUpdatePeriodCharacteristic.stopRespondingToWriteRequests()
        } else {
            self.startAdvertising()
        }
    }
    
    func startAdvertising() {
        let uuid = CBUUID(string:TISensorTag.AccelerometerService.uuid)
        let manager = PeripheralManager.sharedInstance
        // on power on remove all services add service and start advertising
        let startAdvertiseFuture = manager.powerOn().flatmap {_ -> Future<Void> in
            manager.removeAllServices()
            }.flatmap {_ -> Future<Void> in
                manager.addService(self.accelerometerService)
            }.flatmap {_ -> Future<Void> in
                manager.startAdvertising(TISensorTag.AccelerometerService.name, uuids:[uuid])
        }
        startAdvertiseFuture.onSuccess {
            self.presentViewController(UIAlertController.alertWithMessage("powered on and started advertising"), animated:true, completion:nil)
        }
        startAdvertiseFuture.onFailure {error in
            self.presentViewController(UIAlertController.alertOnError(error), animated:true, completion:nil)
            self.startAdvertisingSwitch.on = false
        }
        // stop advertising and updating accelerometer on bluetooth power off
        let powerOffFuture = manager.powerOff().flatmap { _ -> Future<Void> in
            if self.accelerometer.accelerometerActive {
                self.accelerometer.stopAccelerometerUpdates()
                self.enabledSwitch.on = false
            }
            return manager.stopAdvertising()
        }
        powerOffFuture.onSuccess {
            self.startAdvertisingSwitch.on = false
            self.startAdvertisingSwitch.enabled = false
            self.startAdvertisingLabel.textColor = UIColor.lightGrayColor()
            self.presentViewController(UIAlertController.alertWithMessage("powered off and stopped advertising"), animated:true, completion:nil)
        }
        powerOffFuture.onFailure {error in
            self.startAdvertisingSwitch.on = false
            self.startAdvertisingSwitch.enabled = false
            self.startAdvertisingLabel.textColor = UIColor.lightGrayColor()
            self.presentViewController(UIAlertController.alertWithMessage("advertising failed"), animated:true, completion:nil)
        }
        // enable controls when bluetooth is powered on again after stop advertising is successul
        let powerOffFutureSuccessFuture = powerOffFuture.flatmap {_ -> Future<Void> in
            manager.powerOn()
        }
        powerOffFutureSuccessFuture.onSuccess {
            self.presentViewController(UIAlertController.alertWithMessage("restart application"), animated:true, completion:nil)
        }
        // enable controls when bluetooth is powered on again after stop advertising fails
        let powerOffFutureFailedFuture = powerOffFuture.recoverWith {_  -> Future<Void> in
            manager.powerOn()
        }
        powerOffFutureFailedFuture.onSuccess {
            if PeripheralManager.sharedInstance.poweredOn {
                self.presentViewController(UIAlertController.alertWithMessage("restart application"), animated:true, completion:nil)
            }
        }
    }
    
    func respondToWriteRequests() {
        let accelerometerUpdatePeriodFuture = self.accelerometerUpdatePeriodCharacteristic.startRespondingToWriteRequests(2)
        accelerometerUpdatePeriodFuture.onSuccess {request in
            if let value = request.value where value.length > 0 &&  value.length <= 8 {
                self.accelerometerUpdatePeriodCharacteristic.value = value
                self.accelerometerUpdatePeriodCharacteristic.respondToRequest(request, withResult:CBATTError.Success)
                self.updatePeriod()
            } else {
                self.accelerometerUpdatePeriodCharacteristic.respondToRequest(request, withResult:CBATTError.InvalidAttributeValueLength)
            }
        }
        let accelerometerEnabledFuture = self.accelerometerEnabledCharacteristic.startRespondingToWriteRequests(2)
        accelerometerEnabledFuture.onSuccess {request in
            if let value = request.value where value.length == 1 {
                self.accelerometerEnabledCharacteristic.value = value
                self.accelerometerEnabledCharacteristic.respondToRequest(request, withResult:CBATTError.Success)
                self.updateEnabled()
            } else {
                self.accelerometerEnabledCharacteristic.respondToRequest(request, withResult:CBATTError.InvalidAttributeValueLength)
            }
        }
    }
    
    func updateAccelerometerData(data:CMAcceleration) {
        self.xAccelerationLabel.text = NSString(format: "%.2f", data.x) as String
        self.yAccelerationLabel.text = NSString(format: "%.2f", data.y) as String
        self.zAccelerationLabel.text = NSString(format: "%.2f", data.z) as String
        if let xRaw = Int8(doubleValue:(-64.0*data.x)), yRaw = Int8(doubleValue:(-64.0*data.y)), zRaw = Int8(doubleValue:(64.0*data.z)) where self.accelerometerDataCharacteristic.hasSubscriber {
            self.xRawAccelerationLabel.text = "\(xRaw)"
            self.yRawAccelerationLabel.text = "\(yRaw)"
            self.zRawAccelerationLabel.text = "\(zRaw)"
            self.accelerometerDataCharacteristic.updateValueWithString(["xRaw":"\(xRaw)", "yRaw":"\(yRaw)","zRaw":"\(zRaw)"])
        }
    }
    
    func updatePeriod() {
        if let data = self.accelerometerUpdatePeriodCharacteristic.stringValue, period = data["period"], periodRaw = data["periodRaw"], periodInt = Int(period) {
            self.accelerometer.updatePeriod = Double(periodInt)/1000.0
            self.updatePeriodLabel.text =  period
            self.rawUpdatePeriodlabel.text = periodRaw
        }
    }
    
    func updateEnabled() {
        let currentValue = self.enabledSwitch.on ? "Yes" : "No"
        if let data = self.accelerometerEnabledCharacteristic.stringValue, enabled = data.values.first where currentValue != enabled {
            self.enabledSwitch.on = enabled == "Yes"
            self.toggleEnabled(self)
        }
    }
}
