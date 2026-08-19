//
//  TrainType.swift
//  CT
//

import SwiftUI

/// Caltrain's service tiers, derived from a GTFS route's `short_name`.
nonisolated enum TrainType: Sendable {
    case local
    case limited
    case express
    case southCounty

    init(routeShortName: String) {
        switch routeShortName {
        case "Limited": self = .limited
        case "Express": self = .express
        case "South County": self = .southCounty
        default: self = .local
        }
    }

    var label: String {
        switch self {
        case .local: "Local"
        case .limited: "Limited"
        case .express: "Baby Bullet"
        case .southCounty: "South County"
        }
    }

    var badgeColor: Color {
        switch self {
        case .local: Color(.secondaryLabel)
        case .limited: Color("BadgeLimited")
        case .express: Color("BadgeExpress")
        case .southCounty: Color(.secondaryLabel)
        }
    }

    var badgeBackground: Color {
        switch self {
        case .local: Color(.secondarySystemFill)
        case .limited: Color("BadgeLimitedBackground")
        case .express: Color("BadgeExpressBackground")
        case .southCounty: Color(.secondarySystemFill)
        }
    }
}
