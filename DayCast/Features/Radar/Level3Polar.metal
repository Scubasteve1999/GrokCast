#include <metal_stdlib>
using namespace metal;

struct Level3PolarVertexIn {
  float2 merc [[attribute(0)]];
  float level [[attribute(1)]];
};

struct Level3PolarVertexOut {
  float4 position [[position]];
  float2 merc;
};

struct Level3PolarUniforms {
  float4x4 matrix;
  float worldSize;
  float opacity;
  float siteLat;
  float siteLon;
  float maxRangeMeters;
  float metersPerDegLat;
  float metersPerDegLon;
  float pad0;
};

struct Level3PolarLUT {
  uchar4 colors[256];
};

vertex Level3PolarVertexOut level3PolarVertex(
  Level3PolarVertexIn in [[stage_in]],
  constant Level3PolarUniforms &uniforms [[buffer(1)]])
{
  Level3PolarVertexOut out;
  float2 world = in.merc * uniforms.worldSize;
  out.position = uniforms.matrix * float4(world, 0.0, 1.0);
  out.merc = in.merc;
  return out;
}

fragment float4 level3PolarFragment(
  Level3PolarVertexOut in [[stage_in]],
  constant Level3PolarUniforms &uniforms [[buffer(1)]],
  constant Level3PolarLUT &lut [[buffer(2)]],
  texture2d<float> field [[texture(0)]])
{
  // Bilinear sample the wet-only polar field, then snap to a hard NWS hex.
  // Never blend color stops — spatial soft lives in the field texture.
  constexpr sampler polarSampler(
    mag_filter::linear,
    min_filter::linear,
    s_address::repeat,
    t_address::clamp_to_edge);

  float lon = in.merc.x * 360.0 - 180.0;
  float n = 3.14159265358979323846 * (1.0 - 2.0 * in.merc.y);
  float lat = atan(sinh(n)) * 57.29577951308232;
  float east = (lon - uniforms.siteLon) * uniforms.metersPerDegLon;
  float north = (lat - uniforms.siteLat) * uniforms.metersPerDegLat;
  float range = sqrt(east * east + north * north);
  if (range <= 0.0 || range >= uniforms.maxRangeMeters) {
    discard_fragment();
  }
  float az = atan2(east, north);
  if (az < 0.0) {
    az += 6.283185307179586;
  }
  float u = az * 0.15915494309189535;
  float v = range / uniforms.maxRangeMeters;
  float level = field.sample(polarSampler, float2(u, v)).r;
  int idx = int(round(level));
  idx = clamp(idx, 0, 255);
  float4 color = float4(lut.colors[idx]) / 255.0;
  if (color.a < 0.004) {
    discard_fragment();
  }
  return color * uniforms.opacity;
}
