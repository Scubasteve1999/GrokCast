import Foundation
import CoreLocation

struct SavedLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var isCurrent: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, isCurrent: Bool = false) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrent = isCurrent
    }

    static func == (lhs: SavedLocation, rhs: SavedLocation) -> Bool {
        lhs.id == rhs.id
    }
}

extension SavedLocation {
    static var preview: SavedLocation {
        SavedLocation(name: "San Francisco", latitude: 37.7749, longitude: -122.4194)
    }
}