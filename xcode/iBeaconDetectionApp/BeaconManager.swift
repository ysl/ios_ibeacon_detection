//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import Foundation
import UIKit
import CoreLocation
import CoreBluetooth
import UserNotifications

class BeaconManager: NSObject {
    
    // iBeacon configuration: this must match your beacon setup
    let proximityUuid = UUID(uuidString: "CB10023F-A318-3394-4199-A8730C7C1AEC")!
//    let major: UInt16 = 1
//    let minor: UInt16 = 2
    let locationManager = CLLocationManager()
    let peripheralManager = CBPeripheralManager()

    var numberOfDetections = 0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        peripheralManager.delegate = self
        
        let initiateAction = UNNotificationAction(identifier: "initiate", title: "Perform Action", options: [])
        let cancelAction = UNNotificationAction(identifier: "cancel", title: "Cancel",
                                                options: [ .destructive ])
        let initiateCategory = UNNotificationCategory(identifier: "initiate", actions: [initiateAction, cancelAction],
                                                      intentIdentifiers: [], options: [])
        let categories: Set = [ initiateCategory ]
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        
        UNUserNotificationCenter.current().delegate = self
    }
    
    fileprivate func notifyBeaconDetected(beacon: CLBeaconRegion) {
        objc_sync_enter(self)
        numberOfDetections += 1
        let num = numberOfDetections
        objc_sync_exit(self)
        
        NotificationCenter.default.post(name: NSNotification.Name("beaconDetected"), object: beacon)
        clearStaleNotifications {
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.getNotificationSettings { (notificationSettings) in
                if notificationSettings.authorizationStatus == .authorized {
                    let content = UNMutableNotificationContent()
                    content.title = "Beacon detected: \(beacon.identifier)"
                    content.body = "Total # detections: \(num), \(beacon.proximityUUID)"
                    content.sound = UNNotificationSound.default()
                    content.categoryIdentifier = "initiate"
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                } else {
                    print("Not authorized to show notification")
                }
            }
        }
    }
    
    private func clearStaleNotifications(completionHandler: @escaping () -> Void) {
        let unc = UNUserNotificationCenter.current()
        unc.getDeliveredNotifications { (deliveredNotifications) in
            let notificationsToRemove = deliveredNotifications.filter({ $0.request.content.categoryIdentifier == "initiate" })
            unc.removeDeliveredNotifications(withIdentifiers: notificationsToRemove.map({ $0.request.identifier }))
            completionHandler()
        }
    }

    fileprivate func notifyBeaconRanging(beacon: CLBeacon) {
        NotificationCenter.default.post(name: NSNotification.Name("beaconRanging"), object: beacon)
        clearRangingNotifications {
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.getNotificationSettings { (notificationSettings) in
                if notificationSettings.authorizationStatus == .authorized {
                    let content = UNMutableNotificationContent()
                    content.title = "Beacon ranging: \(beacon.major) / \(beacon.minor) / \(beacon.rssi)"
                    content.body = "UUID: \(beacon.proximityUUID)"
                    content.sound = UNNotificationSound.default()
                    content.categoryIdentifier = "ranging"
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                } else {
                    print("Not authorized to show notification")
                }
            }
        }
    }

    private func clearRangingNotifications(completionHandler: @escaping () -> Void) {
        let unc = UNUserNotificationCenter.current()
        unc.getDeliveredNotifications { (deliveredNotifications) in
            let notificationsToRemove = deliveredNotifications.filter({ $0.request.content.categoryIdentifier == "ranging" })
            unc.removeDeliveredNotifications(withIdentifiers: notificationsToRemove.map({ $0.request.identifier }))
            completionHandler()
        }
    }
    
    func isAuthorizerForBeaconMonitoring() -> Bool {
        return CLLocationManager.authorizationStatus() != .denied
    }
}

extension BeaconManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

extension BeaconManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways || status == .authorizedWhenInUse) {
            for monitoredRegion in locationManager.monitoredRegions {
                locationManager.stopMonitoring(for: monitoredRegion)
//                locationManager.stopRangingBeacons(in: monitoredRegion)
            }
            
            let beaconRegion = CLBeaconRegion(proximityUUID: proximityUuid, identifier: "region")
            beaconRegion.notifyEntryStateOnDisplay = true
            locationManager.startMonitoring(for: beaconRegion)
            locationManager.startRangingBeacons(in: beaconRegion)
            print("Subscribing to proximityUUID: \(proximityUuid)")

            print("Started monitoring for beacon regions")
        } else {
            print("Not authorized for beacon region monitoring")
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("ENTER beacon region: \(beaconRegion)")
            self.notifyBeaconDetected(beacon: beaconRegion)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let beaconRegion = region as? CLBeaconRegion {
            print("EXIT beacon region: \(beaconRegion)")
        }
    }

    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Failed monitoring region: \(error.localizedDescription)")
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        print("didRangeBeacons()")
        for beacon in beacons {
            let data = "{\n" +
                "  \"uuid\": \"\(beacon.proximityUUID)\",\n" +
                "  \"major\": \"\(beacon.major)\",\n" +
                "  \"minor\": \"\(beacon.minor)\",\n" +
                "  \"rssi\": \"\(beacon.rssi)\",\n" +
                "}"
            print(data);
            notifyBeaconRanging(beacon: beacon)
        }
    }
}

extension BeaconManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
            case .unknown:
                print("Unknown")
            case .resetting:
                print("Resetting")
            case .unsupported:
                print("unsupported")
            case .unauthorized:
                print("unauthorized")
            case .poweredOff:
                print("poweredOff")
                peripheralManager.stopAdvertising()
                break
            case .poweredOn:
                print("poweredOn")
                let beaconRegion = CLBeaconRegion(proximityUUID: proximityUuid, major: 3, minor: 4, identifier:  "mybeacon" )
                let beaconPeripheralData: NSDictionary = beaconRegion.peripheralData(withMeasuredPower: nil)
                peripheralManager.startAdvertising(beaconPeripheralData as? [String : Any])
                print("startAdvertising")
                break
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if (error != nil) {
            print(error!)
        }
        print("peripheralManagerDidStartAdvertising=" + (peripheral.isAdvertising ? "true" : "false"))
    }
}
