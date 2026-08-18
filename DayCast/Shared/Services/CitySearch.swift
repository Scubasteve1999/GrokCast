import CoreLocation
import MapKit

/// A city the Locations search can add or select.
struct CitySearchResult: Identifiable, Equatable, Sendable {
  let name: String
  let subtitle: String?
  let latitude: Double
  let longitude: Double

  var id: String {
    "\(name)|\(String(format: "%.4f", latitude))|\(String(format: "%.4f", longitude))"
  }

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

/// Worldwide city lookup for Locations. MapKit is biased to the request region,
/// so this never clamps to the current city — that made distant names (Seattle
/// from Olive Branch) fail and look like "no such city."
enum CitySearch {
  /// Broad enough that a city name is not treated as a local POI query.
  static let worldwideRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
    span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 360)
  )

  static func makeMapKitRequest(query: String) -> MKLocalSearch.Request {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = .address
    request.region = worldwideRegion
    request.regionPriority = .default
    return request
  }

  static func displayName(
    city: String?,
    administrativeArea: String?,
    country: String?,
    fallback: String
  ) -> String {
    if let city, !city.isEmpty {
      if let administrativeArea, !administrativeArea.isEmpty {
        return "\(city), \(administrativeArea)"
      }
      if let country, !country.isEmpty {
        return "\(city), \(country)"
      }
      return city
    }
    return fallback
  }

  static func emptyMessage(for query: String) -> String {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "No cities found. Try a city and state, like Seattle, WA."
    }
    return "No cities found for “\(trimmed)”. Try a city and state, like Seattle, WA."
  }

  /// User-facing copy for a failed lookup. `nil` means treat it as an empty result.
  static func errorMessage(for error: Error) -> String? {
    if error is CancellationError { return nil }

    let nsError = error as NSError
    if nsError.domain == MKErrorDomain,
      nsError.code == Int(MKError.Code.placemarkNotFound.rawValue)
    {
      return nil
    }
    if nsError.domain == kCLErrorDomain {
      switch nsError.code {
      case CLError.geocodeFoundNoResult.rawValue, CLError.geocodeFoundPartialResult.rawValue:
        return nil
      case CLError.network.rawValue:
        return "Couldn't search cities. Check your connection and try again."
      default:
        break
      }
    }
    if let urlError = error as? URLError {
      switch urlError.code {
      case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
        return "Couldn't search cities. Check your connection and try again."
      case .timedOut:
        return "City search timed out. Try again."
      default:
        break
      }
    }
    return "Couldn't search cities right now. Try again."
  }

  static func result(
    name: String,
    subtitle: String?,
    latitude: Double,
    longitude: Double
  ) -> CitySearchResult? {
    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return CitySearchResult(
      name: trimmed,
      subtitle: subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
      latitude: latitude,
      longitude: longitude
    )
  }

  static func dedupe(_ results: [CitySearchResult]) -> [CitySearchResult] {
    var kept: [CitySearchResult] = []
    for result in results {
      let isDuplicate = kept.contains {
        $0.name == result.name
          && abs($0.latitude - result.latitude) < 0.01
          && abs($0.longitude - result.longitude) < 0.01
      }
      if !isDuplicate {
        kept.append(result)
      }
    }
    return kept
  }

  static func results(from mapItems: [MKMapItem]) -> [CitySearchResult] {
    dedupe(mapItems.compactMap(result(from:)))
  }

  static func results(from placemarks: [CLPlacemark]) -> [CitySearchResult] {
    dedupe(placemarks.compactMap(result(from:)))
  }

  static func result(from item: MKMapItem) -> CitySearchResult? {
    let placemark = item.placemark
    let coordinate = placemark.coordinate
    let fallback = item.name ?? placemark.name ?? placemark.title ?? ""
    return result(
      name: displayName(
        city: placemark.locality,
        administrativeArea: placemark.administrativeArea,
        country: placemark.country,
        fallback: fallback
      ),
      subtitle: subtitle(locality: placemark.locality, title: placemark.title, coordinate: coordinate),
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
  }

  static func result(from placemark: CLPlacemark) -> CitySearchResult? {
    guard let location = placemark.location else { return nil }
    let coordinate = location.coordinate
    let fallback = placemark.name ?? ""
    return result(
      name: displayName(
        city: placemark.locality,
        administrativeArea: placemark.administrativeArea,
        country: placemark.country,
        fallback: fallback
      ),
      subtitle: subtitle(
        locality: placemark.locality,
        title: formattedAddress(from: placemark),
        coordinate: coordinate
      ),
      latitude: coordinate.latitude,
      longitude: coordinate.longitude
    )
  }

  static func search(query: String) async throws -> [CitySearchResult] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    var mapKitError: Error?
    do {
      let response = try await MKLocalSearch(request: makeMapKitRequest(query: trimmed)).start()
      let mapped = results(from: response.mapItems)
      if !mapped.isEmpty { return mapped }
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      if Task.isCancelled { throw CancellationError() }
      if errorMessage(for: error) == nil {
        mapKitError = nil
      } else {
        mapKitError = error
      }
    }

    do {
      let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
      let mapped = results(from: placemarks)
      if !mapped.isEmpty { return mapped }
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      if Task.isCancelled { throw CancellationError() }
      if let mapKitError { throw mapKitError }
      throw error
    }

    return []
  }

  private static func subtitle(
    locality: String?,
    title: String?,
    coordinate: CLLocationCoordinate2D
  ) -> String? {
    if locality != nil, let title, !title.isEmpty {
      return title
    }
    return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
  }

  /// What Locations should do after the user taps a city.
  /// Free accounts keep one saved city; choosing another replaces that slot
  /// instead of dead-ending on the paywall. A GPS current-location pin is
  /// not replaced — extra saved cities stay Pro.
  static func selection(
    candidate: SavedLocation,
    saved: [SavedLocation],
    canAdd: Bool
  ) -> LocationSearchSelection {
    if let existing = saved.first(where: { isNear($0, candidate) }) {
      return .selectExisting(existing)
    }
    if canAdd {
      return .add
    }
    if saved.count == 1, let only = saved.first, !only.isCurrent {
      return .replace(only)
    }
    return .paywall
  }

  static func isNear(_ lhs: SavedLocation, _ rhs: SavedLocation) -> Bool {
    abs(lhs.latitude - rhs.latitude) < 0.01 && abs(lhs.longitude - rhs.longitude) < 0.01
  }

  private static func formattedAddress(from placemark: CLPlacemark) -> String? {
    var seen = Set<String>()
    let parts = [placemark.name, placemark.locality, placemark.administrativeArea, placemark.country]
      .compactMap { $0 }
      .filter { !$0.isEmpty && seen.insert($0).inserted }
    return parts.joined(separator: ", ").nilIfEmpty
  }
}

enum LocationSearchSelection: Equatable {
  case selectExisting(SavedLocation)
  case add
  case replace(SavedLocation)
  case paywall
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
