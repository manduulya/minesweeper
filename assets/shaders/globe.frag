#include <flutter/runtime_effect.glsl>

uniform vec2  uResolution;
uniform float uLongitude;
uniform float uLatitude;
uniform float uZoom;
uniform float uRoll;
uniform sampler2D uMap;

out vec4 fragColor;

const float PI = 3.14159265358979323846;

// Column-major rotation around the Y axis (horizontal spin)
mat3 rotY(float a) {
  float c = cos(a), s = sin(a);
  return mat3(
     c,  0.0, -s,
    0.0, 1.0, 0.0,
     s,  0.0,  c
  );
}

// Column-major rotation around the X axis (vertical tilt)
mat3 rotX(float a) {
  float c = cos(a), s = sin(a);
  return mat3(
    1.0, 0.0, 0.0,
    0.0,  c,   s,
    0.0, -s,   c
  );
}

// Column-major rotation around the Z axis (twist/roll)
mat3 rotZ(float a) {
  float c = cos(a), s = sin(a);
  return mat3(
     c,  s, 0.0,
    -s,  c, 0.0,
    0.0, 0.0, 1.0
  );
}

vec4 sampleMap(vec3 p) {
  vec3 rp   = rotX(uLatitude) * rotY(uLongitude) * rotZ(uRoll) * p;
  float lat = asin(clamp(rp.y, -1.0, 1.0));
  float lon = atan(rp.x, rp.z);

  // The simplemaps SVG viewBox is 2000×857, so it covers only ±77.13° latitude
  // (not the full ±90°). Using PI for the denominator squeezes countries
  // vertically; using the actual lat range fixes their proportions.
  // lat_max = 90° × (857/2000) × (360/180) / 2  =  77.13° = 1.3461 rad
  const float LAT_MAX = 1.3461;
  float v = 0.5 - lat / (2.0 * LAT_MAX);

  // Latitudes beyond the map's coverage (polar caps) → white
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

  // Normalised [-1, 1] screen coords
  vec2 uv  = (fc - center) / radius;
  vec2 uvZ = uv / max(uZoom, 0.001);

  float z2 = 1.0 - dot(uvZ, uvZ);

  if (z2 < 0.0) {
    // Outside the sphere — show transparent (space/stars show through)
    fragColor = vec4(0.0);
    return;
  }

  // Inside sphere — standard orthographic projection
  vec3 p    = vec3(uvZ.x, -uvZ.y, sqrt(z2));
  fragColor = sampleMap(p);
}
