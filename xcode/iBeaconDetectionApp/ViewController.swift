//
//  Copyright © 2017 Classy Code GmbH. All rights reserved.
//
import UIKit
import UserNotifications
import CoreLocation

class ViewController: UIViewController {

    @IBOutlet weak var statusView: UITextView!
    
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        statusView.text = ""
        NotificationCenter.default.addObserver(self, selector: #selector(onBeaconDetected(notification:)),
                                               name: NSNotification.Name("beaconDetected"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateStatusView()
        super.viewWillAppear(animated)
    }
    
    @objc func onBeaconDetected(notification: Notification) {
        updateStatusView()
    }
    
    private func updateStatusView() {
        UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
            DispatchQueue.main.async {
                let notificationsOk = notificationSettings.authorizationStatus == .authorized
                let notificationsStatusOk = "Notifications permission: \(notificationsOk ? "OK" : "NOK")"
                let locationPermissionGranted = CLLocationManager.authorizationStatus() == .authorizedAlways
                let locationStatusText = "Location permission: \(locationPermissionGranted ? "OK" : "NOK")"
                let beaconManager = AppDelegate.instance.beaconManager!
                let numberOfDetectionsText = "Number of detections: \(beaconManager.numberOfDetections)"
                self.statusView.text = notificationsStatusOk + "\n" + locationStatusText + "\n" + numberOfDetectionsText
            }

        }
    }
    
    @IBAction func onRequestPermissionButtonTouched(_ sender: Any) {
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [ .sound, .alert ]) { (granted, error) in
            self.updateStatusView()
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        updateStatusView()
    }
}
