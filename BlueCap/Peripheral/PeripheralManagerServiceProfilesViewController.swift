//
//  PeripheralManagerServiceProfilesViewController.swift
//  BlueCap
//
//  Created by Troy Stribling on 8/12/14.
//  Copyright (c) 2014 Troy Stribling. The MIT License (MIT).
//

import UIKit
import BlueCapKit
import CoreBluetooth

class PeripheralManagerServiceProfilesViewController : ServiceProfilesTableViewController {
   
    var progressView                    : ProgressView!
    var peripheral                      : String?
    var peripheralManagerViewController : PeripheralManagerViewController?

    
    struct MainStoryboard {
        static let peripheralManagerServiceCell = "PeripheralManagerServiceProfileCell"
    }
    
    override var excludedServices : Array<CBUUID> {
        return PeripheralManager.sharedInstance.services.map{$0.uuid}
    }
    
    override var serviceProfileCell : String {
        return MainStoryboard.peripheralManagerServiceCell
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder:aDecoder)
        self.progressView = ProgressView()
    }
    
    override func viewWillAppear(animated:Bool) {
        super.viewWillAppear(animated)
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"didBecomeActive", name:BlueCapNotification.didBecomeActive, object:nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"didResignActive", name:BlueCapNotification.didResignActive, object:nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func didResignActive() {
        Logger.debug()
        if let peripheralManagerViewController = self.peripheralManagerViewController {
            self.navigationController?.popToViewController(peripheralManagerViewController, animated:false)
        }
    }
    
    func didBecomeActive() {
        Logger.debug()
    }
    
    // UITableViewDelegate
    override func tableView(tableView:UITableView, didSelectRowAtIndexPath indexPath:NSIndexPath) {
        let tags = Array(self.serviceProfiles.keys)
        if let profiles = self.serviceProfiles[tags[indexPath.section]] {
            let serviceProfile = profiles[indexPath.row]
            let service = MutableService(profile:serviceProfile)
            service.characteristicsFromProfiles(serviceProfile.characteristics)
            self.progressView.show()
            let future = PeripheralManager.sharedInstance.addService(service)
            future.onSuccess {
                if let peripheral = self.peripheral {
                    PeripheralStore.addPeripheralService(peripheral, service:service.uuid)
                }
                self.navigationController?.popViewControllerAnimated(true)
                self.progressView.remove()
            }
            future.onFailure {(error) in
                self.presentViewController(UIAlertController.alertOnError("Add Service Error", error:error), animated:true, completion:nil)
                self.navigationController?.popViewControllerAnimated(true)
                self.progressView.remove()
            }
        } else {
            self.navigationController?.popViewControllerAnimated(true)
        }
    }

}
