import Foundation
import MapboxCommon
import MapboxMaps

/// Mapbox fetches IEM RIDGE tiles itself. Intercept N0B PNG bodies and key
/// clear-air clutter to transparent before the raster layer paints. N0S,
/// mosaic, and basemap traffic pass through untouched.
final class IEMN0BTileInterceptor: NSObject, HttpServiceInterceptorInterface {
  static let shared = IEMN0BTileInterceptor()

  private static var didInstall = false

  static func install() {
    guard !didInstall else { return }
    didInstall = true
    HttpServiceFactory.setHttpServiceInterceptorForInterceptor(shared)
  }

  func onRequest(
    for request: HttpRequest,
    continuation: @escaping HttpServiceInterceptorRequestContinuation
  ) {
    if let png = Level3PolarTilePainter.png(forTileURL: request.url) {
      continuation(
        HttpRequestOrResponse.fromHttpResponse(
          Self.response(requestId: 0, request: request, png: png)))
      return
    }
    continuation(HttpRequestOrResponse.fromHttpRequest(request))
  }

  func onResponse(
    for response: HttpResponse,
    continuation: @escaping HttpServiceInterceptorResponseContinuation
  ) {
    if let png = Level3PolarTilePainter.png(forTileURL: response.request.url) {
      continuation(
        Self.response(
          requestId: response.requestId, request: response.request, png: png))
      return
    }
    guard IEMSiteReflectivityPaint.shouldProcess(url: response.request.url),
      case .success(let payload) = response.result,
      payload.code == 200,
      !payload.data.isEmpty
    else {
      continuation(response)
      return
    }

    let keyed = IEMSiteReflectivityPaint.keyClutter(in: payload.data)
    let data = HttpResponseData(
      headers: payload.headers, code: payload.code, data: keyed)
    let rewritten = HttpResponse(
      identifier: response.requestId, request: response.request, result: .success(data))
    continuation(rewritten)
  }

  private static func response(
    requestId: UInt64, request: HttpRequest, png: Data
  ) -> HttpResponse {
    let payload = HttpResponseData(
      headers: ["content-type": "image/png", "cache-control": "no-cache"],
      code: 200,
      data: png)
    return HttpResponse(
      identifier: requestId, request: request, result: .success(payload))
  }
}
