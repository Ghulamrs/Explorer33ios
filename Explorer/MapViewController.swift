//
//  MapViewController.swift
//  Explorer
//
//  Created by Home on 7/16/18.
//  Copyright © 2018 Home. All rights reserved.
//

import UIKit
import GoogleMaps
import CoreFoundation
import CoreLocation
import Foundation
import Darwin

class MapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {

    var locationManager: CLLocationManager!
    var mapView: GMSMapView!
    var camera: GMSCameraPosition!
    var markers: [GMSMarker] = []
    let firstView = ViewController()
    var park: CLLocation = CLLocation(latitude: 0, longitude: 0)
    var firstCall: Bool = true // One-time check to get user's names from ground
    var lox: LocationEx? // ground data location set
    var pid: UInt = 0 // self id
    var tid: UInt = 1 // tracking id

    var location: [CLLocation] = [] // current location set
    var reachability: Reachability? = Reachability.networkReachabilityForInternetConnection()
    var isOnline: Bool = false // status of reachability
    var isOutage: Bool = true  // status of outage-buffer - sql-based un-sent data on app startup
    let deltaCount: Int32 = 10 // threshold for no of locations not sent - after which use sql
    let distFilter: CLLocationDistance = 35.0
    var sql = SQLite()

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityDidChange(_:)), name: NSNotification.Name(rawValue: ReachabilityDidChangeNotificationName), object: nil)
        _ = reachability?.startNotifier()
        
        initMapView()
        configureLocationManager()
        checkReachability()
        let info = firstView.user.loadUserInfo()
        if  info != nil {
            self.pid = info as! UInt
            self.tid = self.pid
            initializeMarkersAtParking()
            installSenderTask()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkReachability()
    }

    func initMapView() {
        camera = GMSCameraPosition.camera(withLatitude: park.coordinate.latitude, longitude: park.coordinate.longitude, zoom: 6)
        mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.mapType = GMSMapViewType.terrain

        mapView.isMyLocationEnabled = true
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        mapView.delegate = self
        self.view = mapView
    }

    func installSenderTask() {
        let locDespQueue = DispatchQueue(label: "locDespQueue", qos: .background)
        locDespQueue.async {
            while true {
                if self.isOnline {
                    if self.isOutage { self.clearSqlData() }
                    else if self.location.count > 0 { self.sendLocationArray() }
                    else { self.recvLocation(); usleep(1500000) }
                }
                else { usleep(3000000) } // not reachable

                DispatchQueue.main.sync {
                    self.updateMarkers()
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func mapView(_ mapView: GMSMapView, didLongPressInfoWindowOf marker: GMSMarker) {
        if tid != pid { markers[Int(tid-1)].zIndex = 0 }
        tid = firstView.user.findUserId(name: marker.title!)
        if tid != pid { markers[Int(tid-1)].zIndex = 2 }

        let alert = UIAlertController(title: "Camera follows "+marker.title!, message: "Tap to change.", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func initializeMarkersAtParking() {
        markers = [GMSMarker]()
        for i in 0..<firstView.user.usersCount {
            let mark = GMSMarker();
            if i==pid-1 { // Take this user loc(lat,long) from his stored settings
                mark.position = CLLocationCoordinate2DMake(firstView.user.userLat, firstView.user.userLng)
                mark.icon = GMSMarker.markerImage(with: UIColor.green)
                mark.zIndex = 1
            }
            else { // Take others loc from general marker parking(lat: 0, long: 0)
                mark.position = CLLocationCoordinate2DMake(park.coordinate.latitude, park.coordinate.longitude)
            }
            mark.snippet = "user #"+String(i+1)
            markers.append(mark)
            markers[i].map = mapView
        }
    }

    func configureLocationManager() {
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters //kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.requestAlwaysAuthorization() // requestWhenInUseAuthorization()
        locationManager.delegate = self

        locationManager.distanceFilter = distFilter
        locationManager.startUpdatingLocation()

        locationManager.headingFilter = 25.0
        locationManager.startUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.park = loc
        if self.park.horizontalAccuracy <= distFilter && self.park.verticalAccuracy <= distFilter {
            location.append(self.park)
            if location.count >= deltaCount { saveSqlData() }
        }

        if isOnline { mapView.animate(toLocation: self.park.coordinate) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        if firstCall {
            mapView.animate(toLocation: park.coordinate)
        }
        else {
            let id = Int(tid - 1)
            mapView.animate(toLocation: markers[id].position)
        }
        mapView.animate(toBearing: heading.trueHeading)
    }

    func updateMarkers() {
        guard let userLocations = self.lox?.locations else { return }
        for loc in userLocations {
            let id = Int(loc.id)!
            if 0 < id && id <= markers.count {
                markers[id-1].position = CLLocationCoordinate2DMake(Double(loc.lat)!, Double(loc.lng)!)
                if firstCall==true {
                    markers[id-1].title = loc.name!
                }
            }
        }

        if firstCall==true {
            firstCall = false
            welcomeToMorningWalk()
            saveUserList()
        }
    }

    func welcomeToMorningWalk() {
        let alertController = UIAlertController(title: "Welcome to Morning Walk", message: "Version 2.1.33", preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    func saveUserList() {
        var dict = [UInt: String]()
        for loc in (self.lox?.locations)! {
            let id = UInt(loc.id)!
            dict[id] = loc.name!
        }
        
        firstView.user.setUsers(data: dict)
    }

    func sendLocation(loc: CLLocation) {
        let url = URL(string: firstView.user.myUrl + "setLocationii.php")
        var request = URLRequest(url: url!, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        request.httpMethod = "POST"
        
        var postString = String("pid=") + String(pid) + String("&par=") +
            String(loc.coordinate.latitude) + "," +
            String(loc.coordinate.longitude) + "," +
            String(loc.altitude) + "," +
            String(loc.speed)

        postString += (firstCall==true ? ",1" : ",2")
        request.httpBody = postString.data(using: .utf8, allowLossyConversion: true)
        URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
 
            do {
                if data == nil {
                    return
                }
                let decoder = JSONDecoder()
                self.lox = try decoder.decode(LocationEx.self, from: data!)
                DispatchQueue.main.sync {
                    self.lox = self.lox
                }
            }
            catch let parsingError {
                print("Error: ", parsingError)
            }
        }).resume()
    }

    func recvLocation() {
        let url = URL(string: firstView.user.myUrl + "setLocationii.php")
        var request = URLRequest(url: url!, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 60)
        request.httpMethod = "POST"

        let postString = String("pid=") + String(pid) + String("&par=0,0,0,0,0") // Don't use setLocation
        request.httpBody = postString.data(using: .utf8, allowLossyConversion: true)
        URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in

            do {
                if data == nil {
                    return
                }
                let decoder = JSONDecoder()
                self.lox = try decoder.decode(LocationEx.self, from: data!)
                DispatchQueue.main.sync {
                    self.lox = self.lox
                }
            }
            catch let parsingError {
                print("Error: ", parsingError)
            }
        }).resume()
    }

    deinit {
        firstView.user.userLat = park.coordinate.latitude
        firstView.user.userLng = park.coordinate.longitude
        firstView.user.saveUserInfo()

        NotificationCenter.default.removeObserver(self)
        reachability?.stopNotifier()
    }
    
    @objc func reachabilityDidChange(_ notification: Notification) {
        checkReachability()
    }
    
    func checkReachability() {
        guard let r = reachability else { return }
        if r.isReachable  {
            self.isOnline = true
        } else {
            self.isOnline = false
        }
    }

    func sendLocationArray() {
        while location.count > 0 {
            self.sendLocation(loc: location[0])
            location.remove(at: 0)
            usleep(1500000)
        }
    }
    
    func saveSqlData() {
        while location.count > 0 {
            sql.addLocation(loc: location[0])
            location.remove(at: 0)
        }
        if !isOutage { isOutage = true }
    }

    func clearSqlData() {
        let sqlLocations = sql.readLocations(deltaCount)
        for i in 0..<sqlLocations.count {
            self.sendLocation(loc: sqlLocations[i])
            usleep(250000)
        }
        
        if sqlLocations.count < deltaCount {
            isOutage = false
        }
    }
}
