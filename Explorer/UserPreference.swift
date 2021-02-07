//
//  UserPreference.swift
//  Explorer
//
//  Created by Home on 8/2/18.
//  Copyright © 2018 Home. All rights reserved.
//

import Foundation

class UserPreference {
    var pid  : UInt!
    var name : String!
    var pswd : String!
    var userLat: Double! // home
    var userLng: Double! // home
    var users = [UInt: String]()
    var usersCount: Int!

    var myUrl = "http://idzeropoint.com/"
//    var myUrl = "http://3.92.12.25/service/"
//    let myUrl = "http://18.210.75.31/morningwalk/service/"
    init() {
        self.pid = 1
        self.name = "gra"
        self.userLat = 33.6938 // zero point
        self.userLng = 73.0652  // zero point
        self.usersCount = 12
    }

    func update(usr: String, psw: String) {
        name = usr
        pswd = psw
    }

    func saveUserInfo() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(self.pid,        forKey: "pid")
        userDefaults.set(self.name,       forKey: "name")
        userDefaults.set(self.usersCount, forKey: "usercount")
        userDefaults.set(self.userLat,    forKey: "userlat")
        userDefaults.set(self.userLng,    forKey: "userlng")
        userDefaults.synchronize()
//        print("UserID: \(self.pid), Name: \(self.name)")
    }

    func loadUserInfo() -> Optional<Any> {
        if let key = UserDefaults.standard.object(forKey: "pid") {
            self.pid        = key as? UInt
            self.name       = (UserDefaults.standard.object(forKey: "name")      as! String)
            self.usersCount = (UserDefaults.standard.object(forKey: "usercount") as! Int)
            self.userLat    = (UserDefaults.standard.object(forKey: "userlat")   as! Double)
            self.userLng    = (UserDefaults.standard.object(forKey: "userlng")   as! Double)

            return self.pid
        }

        return nil
    }

    func findUserId(name: String) -> UInt {
        for (key, value) in self.users {
            if value.contains(name) && name.contains(value) {
                return key
            }
        }

        return 0
    }
    
    func setUsers(data: [UInt: String]) {
        self.users = data
    }
}
