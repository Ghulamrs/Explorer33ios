//
//  Records.swift
//  Explorer
//
//  Created by Home on 8/7/18.
//  Upated by Home on 16/1/19.
//  Copyright © 2018 Home. All rights reserved.
//

import Foundation

class LocationEx : Codable {
    var locations : [Location]
    
    init(loc : [Location]) {
        self.locations = loc
    }
}

class Location : Codable {
    var id:   String
    var lat:  String
    var lng:  String
    var name: String?

    init(id: String, lat: String, lng: String, name: String) {
        self.id   = id
        self.lat  = lat
        self.lng  = lng
        self.name = name
    }
    
    convenience init(id: String, lat: String, lng: String) {
        self.init(id: id, lat: lat, lng: lng, name: "")
    }
}
