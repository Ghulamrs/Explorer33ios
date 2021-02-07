//
//  SQLite.swift
//  Explorer
//
//  Created by Home on 1/22/19.
//  Copyright © 2019 Home. All rights reserved.
//

import Foundation
import CoreLocation
import SQLite3

class SQLite {
    fileprivate var idx: Int32
    fileprivate var db: OpaquePointer?
    
    init() {
        let fileUrl = try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false).appendingPathComponent("myLocations.sqlite")
        
        if sqlite3_open(fileUrl.path, &db) != SQLITE_OK {
            print("Error openeing database")
        }
        
        let TABLE_NAME = "locations"
        let COLUMN_IDX = "idx"
        let COLUMN_LAT = "lat"
        let COLUMN_LNG = "lng"
        let COLUMN_ALT = "alt"
        let COLUMN_VEL = "vel"
        let createTableQuery = "CREATE TABLE IF NOT EXISTS " + TABLE_NAME + "(" +
            COLUMN_IDX + " INTEGER PRIMARY KEY AUTOINCREMENT," +
            COLUMN_LAT + " FLOAT," +
            COLUMN_LNG + " FLOAT," +
            COLUMN_ALT + " FLOAT," +
            COLUMN_VEL + " FLOAT)";
        idx = 0
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            print("Error creating table !!!")
        }
    }

    func addLocation(loc: CLLocation) {
        idx += 1
        var iState: OpaquePointer?
        let insertString = "INSERT INTO locations (idx, lat, lng, alt, vel) VALUES (?, ?, ?, ?, ?)"
        if sqlite3_prepare(db, insertString, -1, &iState, nil) != SQLITE_OK { print("Error binding querry!") }
        if sqlite3_bind_int(   iState, 1, idx)                   != SQLITE_OK { print("Error binding index") }
        if sqlite3_bind_double(iState, 2, loc.coordinate.latitude)  != SQLITE_OK { print("Error binding latitude") }
        if sqlite3_bind_double(iState, 3, loc.coordinate.longitude) != SQLITE_OK { print("Error binding longitude") }
        if sqlite3_bind_double(iState, 4, loc.altitude)          != SQLITE_OK { print("Error binding altitude") }
        if sqlite3_bind_double(iState, 5, loc.speed)           != SQLITE_OK { print("Error binding speed") }
        if sqlite3_step(iState) == SQLITE_DONE {
            sqlite3_finalize(iState)
        }
    }

    func readLocations(_ delCount: Int32) -> [CLLocation] {
        let loc = readNext10Locations(delCount)
        for i in 0..<loc.count {
            deleteLocation(index: Int32(loc[i].horizontalAccuracy))
        }
        return loc
    }

    func readNext10Locations(_ delCount: Int32) -> [CLLocation] {
        var count: Int32 = 0
        var locations = [CLLocation]()
        var selectStatement: OpaquePointer?
        let queryString = "SELECT * FROM locations ORDER BY idx ASC"
        
        sqlite3_prepare(db, queryString, -1, &selectStatement, nil)
        while(sqlite3_step(selectStatement) == SQLITE_ROW) {
            count += 1
            let idx = sqlite3_column_int(selectStatement, 0)
            let lat = sqlite3_column_double(selectStatement, 1)
            let lng = sqlite3_column_double(selectStatement, 2)
            let alt = sqlite3_column_double(selectStatement, 3)
            let vel = sqlite3_column_double(selectStatement, 4)
            
            let pos = CLLocationCoordinate2DMake(Double(lat), Double(lng))
            let loc: CLLocation = CLLocation(coordinate: pos, altitude: Double(alt), horizontalAccuracy: CLLocationAccuracy(idx), verticalAccuracy: 0, course: 0.0, speed: Double(vel), timestamp: Date(timeIntervalSince1970: 0))
            locations.append(loc)
            if count == delCount { break }
        }
        sqlite3_finalize(selectStatement)
        
        return locations
    }
    
    func deleteLocations() {
        let deleteStatementStirng = "DELETE FROM locations"
        var deleteStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, deleteStatementStirng, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                sqlite3_finalize(deleteStatement)
            }
        }
    }
    
    func deleteLocation(index: Int32) {
        let deleteStatementStirng = "DELETE FROM locations WHERE idx="+String(index)
        var deleteStatement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, deleteStatementStirng, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                sqlite3_finalize(deleteStatement)
            }
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
}
