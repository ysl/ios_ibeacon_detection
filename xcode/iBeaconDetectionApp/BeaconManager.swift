//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import Foundation
import UIKit
import CoreLocation
import UserNotifications

class BeaconManager: NSObject {
    
    // iBeacon configuration: this must match your beacon setup
    let proximityUuid = UUID(uuidString: "33013f7f-cb46-4db6-b4be-542c310a81eb")!
    let major: UInt16 = 204
    let minorRange: CountableRange<UInt16> = 1..<21
    let locationManager = CLLocationManager()

    var numberOfDetections = 0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        
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
                    content.title = "Beacon detected: \(beacon.major!) / \(beacon.minor!)"
                    content.body = "Total # detections: \(num)"
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
            }
            
            for minor in minorRange {
                let beaconRegion = CLBeaconRegion(proximityUUID: proximityUuid, major: major,
                                                  minor: minor, identifier: "region\(minor)")
                beaconRegion.notifyEntryStateOnDisplay = true
                locationManager.startMonitoring(for: beaconRegion)
                print("Subscribing to proximityUUID: \(proximityUuid) major: \(major) minor: \(minor)")
            }
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
}
