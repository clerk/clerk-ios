//
//  Session+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 1/19/25.
//

import Foundation
import Clerk

extension Session {
    
    var browserDisplayText: String {
        var string = ""
        if let browserName = latestActivity?.browserName {
            string += browserName
        }
        
        if let browserVersion = latestActivity?.browserVersion {
            string += " \(browserVersion)"
        }
        
        return string
    }
    
    var ipAddressDisplayText: String {
        var string = ""
        if let ipAddress = latestActivity?.ipAddress {
            string += ipAddress
        }
        
        if latestActivity?.city != nil || latestActivity?.country != nil {
            var cityCountry: [String] = []
            
            if let city = latestActivity?.city {
                cityCountry.append(city)
            }
            if let country = latestActivity?.country {
                cityCountry.append(country)
            }
            
            var locationString = " (" + cityCountry.joined(separator: ", ")
            locationString.append(")")
            
            string += locationString
        }
        
        return string
    }
    
    var identifier: String? {
        publicUserData?.identifier
    }
    
}
