import Foundation

/// Radar diagnostics: provider selection, fallback reasons, and load lifecycle.
///
/// The radar path picks between IEM, RainViewer, OpenWeatherMap and Xweather at
/// runtime and silently degrades when one is unavailable, so these breadcrumbs are
/// the only way to tell *which* provider produced the frames on screen. They stay
/// out of Release builds: `@autoclosure` means the interpolation is never even
/// evaluated there.
func radarLog(_ message: @autoclosure () -> String) {
  #if DEBUG
    print(message())
  #endif
}
