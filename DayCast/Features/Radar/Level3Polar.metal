#include <metal_stdlib>
using namespace metal;

struct Level3PolarVertexIn {
  float2 merc [[attribute(0)]];
  float level [[attribute(1)]];
};

struct Level3PolarVertexOut {
  float4 position [[position]];
  float level;
};

struct Level3PolarUniforms {
  float4x4 matrix;
  float worldSize;
  float opacity;
  float pad0;
  float pad1;
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
  out.level = in.level;
  return out;
}

fragment float4 level3PolarFragment(
  Level3PolarVertexOut in [[stage_in]],
  constant Level3PolarUniforms &uniforms [[buffer(1)]],
  constant Level3PolarLUT &lut [[buffer(2)]])
{
  int idx = int(round(in.level));
  idx = clamp(idx, 0, 255);
  float4 color = float4(lut.colors[idx]) / 255.0;
  if (color.a < 0.004) {
    discard_fragment();
  }
  return color * uniforms.opacity;
}
