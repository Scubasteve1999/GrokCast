import CoreLocation
import XCTest

@testable import GrokCast

/// Logic-facing checks for site-product load metadata. Network calls stay in
/// the service; these assert the advisory/fallback contract the UI depends on.
final class IEMRadarSiteFallbackTests: XCTestCase {
  func testSiteFrameLoadFlagsFallbackWhenSitesDiffer() {
    let home = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.3)
    let neighbor = IEMRadarService.Site(id: "OHX", name: "Nashville", lon: -86.5, lat: 36.2)
    let frame = RadarFrame(
      provider: .iem,
      kind: .livePrecipitation,
      tileEpoch: 1,
      timestamp: Date(),
      tileURLTemplates: ["https://example.com/{z}/{x}/{y}.png"]
    )
    let load = IEMRadarService.SiteFrameLoad(
      frames: [frame],
      site: neighbor,
      preferredSite: home,
      isFallback: true,
      isStale: false
    )
    XCTAssertTrue(load.isFallback)
    XCTAssertEqual(load.site.id, "OHX")
    XCTAssertEqual(load.preferredSite.id, "NQA")
  }

  func testSiteFrameLoadMarksStaleWhenNewestIsOld() {
    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.3)
    let old = Date().addingTimeInterval(-30 * 60)
    let frame = RadarFrame(
      provider: .iem,
      kind: .livePrecipitation,
      tileEpoch: Int(old.timeIntervalSince1970),
      timestamp: old,
      tileURLTemplates: ["https://example.com/{z}/{x}/{y}.png"]
    )
    let load = IEMRadarService.SiteFrameLoad(
      frames: [frame],
      site: site,
      preferredSite: site,
      isFallback: false,
      isStale: true
    )
    XCTAssertTrue(load.isStale)
    XCTAssertGreaterThan(load.newestScanAge, IEMRadarService.staleScanThreshold)
  }

  /// Ancient home-site volumes must not win when a neighbor has a primary hit.
  func testPrimaryNeighborBeatsStaleHomeInPicker() {
    let home = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.3)
    let neighbor = IEMRadarService.Site(id: "OHX", name: "Nashville", lon: -86.5, lat: 36.2)

    let ancient = Date().addingTimeInterval(-12 * 3600)
    let fresh = Date().addingTimeInterval(-5 * 60)

    let staleHome = IEMRadarService.siteFrameLoad(
      frames: [
        RadarFrame(
          provider: .iem,
          kind: .livePrecipitation,
          tileEpoch: Int(ancient.timeIntervalSince1970),
          timestamp: ancient,
          tileURLTemplates: ["https://example.com/old/{z}/{x}/{y}.png"]
        )
      ],
      site: home,
      preferred: home
    )!
    let freshNeighbor = IEMRadarService.siteFrameLoad(
      frames: [
        RadarFrame(
          provider: .iem,
          kind: .livePrecipitation,
          tileEpoch: Int(fresh.timeIntervalSince1970),
          timestamp: fresh,
          tileURLTemplates: ["https://example.com/new/{z}/{x}/{y}.png"]
        )
      ],
      site: neighbor,
      preferred: home
    )!

    // Pass 1 only has the neighbor (home empty in 3h window).
    let picked = IEMRadarService.pickSiteFrameLoad(
      primaryHits: [freshNeighbor],
      extendedHits: [staleHome]
    )
    XCTAssertEqual(picked?.site.id, "OHX")
    XCTAssertTrue(picked?.isFallback == true)
  }

  /// When nothing is in the primary window, pick the freshest extended volume.
  func testExtendedPassPicksFreshestNotNearest() {
    let home = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.3)
    let neighbor = IEMRadarService.Site(id: "OHX", name: "Nashville", lon: -86.5, lat: 36.2)

    let older = Date().addingTimeInterval(-10 * 3600)
    let newer = Date().addingTimeInterval(-4 * 3600)

    let staleHome = IEMRadarService.siteFrameLoad(
      frames: [
        RadarFrame(
          provider: .iem,
          kind: .livePrecipitation,
          tileEpoch: Int(older.timeIntervalSince1970),
          timestamp: older,
          tileURLTemplates: ["https://example.com/a/{z}/{x}/{y}.png"]
        )
      ],
      site: home,
      preferred: home
    )!
    let lessStaleNeighbor = IEMRadarService.siteFrameLoad(
      frames: [
        RadarFrame(
          provider: .iem,
          kind: .livePrecipitation,
          tileEpoch: Int(newer.timeIntervalSince1970),
          timestamp: newer,
          tileURLTemplates: ["https://example.com/b/{z}/{x}/{y}.png"]
        )
      ],
      site: neighbor,
      preferred: home
    )!

    let picked = IEMRadarService.pickSiteFrameLoad(
      primaryHits: [],
      extendedHits: [staleHome, lessStaleNeighbor]
    )
    XCTAssertEqual(picked?.site.id, "OHX")
  }

  func testSiteFrameLoadReturnsNilForEmptyFrames() {
    let site = IEMRadarService.Site(id: "NQA", name: "Memphis", lon: -89.9, lat: 35.3)
    XCTAssertNil(IEMRadarService.siteFrameLoad(frames: [], site: site, preferred: site))
  }
}
