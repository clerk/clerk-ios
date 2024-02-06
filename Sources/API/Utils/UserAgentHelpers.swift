//
//  UserAgentHelpers.swift
//
//
//  Created by Mike Pitre on 11/21/23.
//

import Foundation
import UIKit

struct UserAgentHelpers {
    
    //eg. Darwin/16.3.0
    private static func DarwinVersion() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let dv = String(bytes: Data(bytes: &sysinfo.release, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
        return "Darwin/\(dv)"
    }
    //eg. CFNetwork/808.3
    private static func CFNetworkVersion() -> String {
        let dictionary = Bundle(identifier: "com.apple.CFNetwork")?.infoDictionary!
        let version = dictionary?["CFBundleShortVersionString"] as! String
        return "CFNetwork/\(version)"
    }

    //eg. iOS/10_1
    private static func deviceVersion() -> String {
        let currentDevice = UIDevice.current
        return "\(currentDevice.systemName)/\(currentDevice.systemVersion)"
    }
    
    //eg. iPhone5,2
    private static func deviceName() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
    }
    
    //eg. MyApp/1
    private static func appNameAndVersion() -> String {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let name = dictionary["CFBundleName"] as! String
        return "\(name)/\(version)"
    }
    
    static var userAgentString: String {
        var userAgent = "\(appNameAndVersion()) \(deviceName()) \(deviceVersion()) \(CFNetworkVersion()) \(DarwinVersion())"
        #if os(iOS)
            userAgent += " Mobile"
        #endif
        return userAgent
    }
    
}
