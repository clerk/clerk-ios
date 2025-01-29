//
//  InstanceEnvironmentType.swift
//  Clerk
//
//  Created by Mike Pitre on 1/27/25.
//

/// An enumeration representing the type of environment for an instance.
///
/// This is used to distinguish between production and development environments, allowing for
/// environment-specific behavior or configurations.
public enum InstanceEnvironmentType {
    
    /// Represents a production environment.
    case production
    
    /// Represents a development environment.
    case development
}

