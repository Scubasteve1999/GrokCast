#include <metal_stdlib>
using namespace metal;

struct Level3PolarVertexIn {
  float2 merc [[attribute(0)]];
  uchar4 rgba [[attribute(1)]];
};

struct Level3PolarVertexOut {
  float4 position [[position]];
  float4 color;
};

struct Level3PolarUniforms {
  float4x4 matrix;
  float worldSize;
  float opacity;
  float pad0;
  float pad1;
};

vertex Level3PolarVertexOut level3PolarVertex(
  Level3PolarVertexIn in [[stage_in]],
  constant Level3PolarUniforms &uniforms [[buffer(1)]])
{
  Level3PolarVertexOut out;
  float2 world = in.merc * uniforms.worldSize;
  out.position = uniforms.matrix * float4(world, 0.0, 1.0);
  float4 color = float4(in.rgba) / 255.0;
  color *= uniforms.opacity;
  out.color = color;
  return out;
}

fragment float4 level3PolarFragment(Level3PolarVertexOut in [[stage_in]]) {
  return in.color;
}
