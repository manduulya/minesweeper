#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uZoom;
uniform vec3 uRow0;
uniform vec3 uRow1;
uniform vec3 uRow2;
uniform sampler2D uMap;

out vec4 fragColor;

const float PI = 3.14159265358979323846;

vec4 sampleMap(vec3 p) {
  // Apply rotation: rp = R * p  (R stored as three row-vectors)
  vec3 rp = vec3(dot(uRow0, p), dot(uRow1, p), dot(uRow2, p));

  float lat = asin(clamp(rp.y, -1.0, 1.0));
  float lon = atan(rp.x, rp.z);

  const float LAT_MAX = 1.3461;
  float v = 0.5 - lat / (2.0 * LAT_MAX);

  if (v < 0.0 || v > 1.0) {
    return vec4(1.0, 1.0, 1.0, 1.0);
  }

  vec2 texUV = vec2(0.5 + lon / (2.0 * PI), v);
  return texture(uMap, texUV);
}

void main() {
  vec2  fc     = FlutterFragCoord().xy;
  float radius = min(uResolution.x, uResolution.y) * 0.5;
  vec2  center = uResolution * 0.5;

  vec2 uv  = (fc - center) / radius;
  vec2 uvZ = uv / max(uZoom, 0.001);

  float z2 = 1.0 - dot(uvZ, uvZ);

  if (z2 < 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  vec3 p    = vec3(uvZ.x, -uvZ.y, sqrt(z2));
  fragColor = sampleMap(p);
}
