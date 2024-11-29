struct Frame {
    resolutionTime: vec4f,
    input: vec4u,
}
struct GameState {
    motion: vec4f,
    ship: vec4f,
    status: vec4f,
    camera: vec4f,
}
struct VertexOut {
    @builtin(position) position: vec4f
}
@group(0) @binding(0) var<uniform> frame: Frame;
@group(0) @binding(1) var<storage, read> game: GameState;
@group(0) @binding(2) var noiseTexture: texture_2d<f32>;
@group(0) @binding(3) var noiseSampler: sampler;
const TITLE = array<u32, 12>(76u,85u,78u,65u,82u,32u,76u,65u,78u,68u,69u,82u);
const PLAY = array<u32, 19>(80u,82u,69u,83u,83u,32u,69u,78u,84u,69u,82u,32u,84u,79u,32u,80u,76u,65u,89u);
const START = array<u32, 10>(83u,84u,65u,82u,84u,32u,71u,65u,77u,69u);
const HOWTO = array<u32, 11>(72u,79u,87u,32u,84u,79u,32u,80u,76u,65u,89u);
const CONTROLS = array<u32, 8>(67u,79u,78u,84u,82u,79u,76u,83u);
const ROTATE = array<u32, 18>(82u,79u,84u,65u,84u,69u,32u,83u,72u,73u,80u,32u,65u,82u,82u,79u,87u,83u);
const BOOST = array<u32, 14>(66u,79u,79u,83u,84u,69u,82u,83u,32u,83u,80u,65u,67u,69u);
const LAND = array<u32, 29>(76u,65u,78u,68u,32u,83u,81u,85u,65u,82u,69u,76u,89u,32u,79u,78u,32u,67u,79u,76u,79u,82u,69u,68u,32u,80u,65u,68u,83u);
const PADVALUES = array<u32, 10>(80u,65u,68u,32u,86u,65u,76u,85u,69u,83u);
const RETURN_TEXT = array<u32, 21>(80u,82u,69u,83u,83u,32u,69u,78u,84u,69u,82u,32u,84u,79u,32u,82u,69u,84u,85u,82u,78u);
const SCORE = array<u32, 5>(83u,67u,79u,82u,69u);
const FUEL = array<u32, 4>(70u,85u,69u,76u);
const ALT = array<u32, 3>(65u,76u,84u);
const HVEL = array<u32, 5>(72u,45u,86u,69u,76u);
const VVEL = array<u32, 5>(86u,45u,86u,69u,76u);
const DEAD = array<u32, 4>(68u,69u,65u,68u);
const FUEL_LOST = array<u32, 13>(49u,48u,48u,32u,70u,85u,69u,76u,32u,76u,79u,83u,84u);
const SUCCESS = array<u32, 8>(83u,85u,67u,67u,69u,83u,83u,33u);
const GAME_OVER = array<u32, 9>(71u,65u,77u,69u,32u,79u,86u,69u,82u);
const LOW_FUEL = array<u32, 8>(76u,79u,87u,32u,70u,85u,69u,76u);
@vertex
fn vertexMain(@builtin(vertex_index) index: u32) -> VertexOut {
    let p = array<vec2f, 3>(vec2f(-1.0, -1.0), vec2f(3.0, -1.0), vec2f(-1.0, 3.0));
    var out: VertexOut;
    out.position = vec4f(p[index], 0.0, 1.0);
    return out;
}
fn noiseAt(uv: vec2f) -> f32 { return textureSample(noiseTexture, noiseSampler, uv).r; }
fn hash21(p: vec2f) -> f32 { return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453); }
fn valueNoise(p: vec2f) -> f32 {
    let cell = floor(p);
    let local = fract(p);
    let blend = local * local * (3.0 - 2.0 * local);
    let a = hash21(cell);
    let b = hash21(cell + vec2f(1.0, 0.0));
    let c = hash21(cell + vec2f(0.0, 1.0));
    let d = hash21(cell + vec2f(1.0, 1.0));
    return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}
fn geologyPartial(p: vec2f) -> f32 {
    return (valueNoise(p) + valueNoise(p * 2.03 + vec2f(3.1, -1.7)) * 0.5 + valueNoise(p * 4.07 + vec2f(-2.4, 4.6)) * 0.25) * 0.5714;
}
fn geologyFbm(p: vec2f) -> f32 {
    return (valueNoise(p) + valueNoise(p * 2.03 + vec2f(3.1, -1.7)) * 0.5 + valueNoise(p * 4.07 + vec2f(-2.4, 4.6)) * 0.25 + valueNoise(p * 8.11 + vec2f(5.2, 2.8)) * 0.125 + valueNoise(p * 16.17 + vec2f(-6.8, -3.4)) * 0.0625) * 0.533333;
}
fn starLayer(uv: vec2f, time: f32, gridSize: vec2f, threshold: f32) -> f32 {
    let grid = uv * gridSize;
    let cellId = floor(grid);
    let cell = fract(grid) - 0.5;
    let seed = hash21(cellId);
    let radius = mix(0.045, 0.115, hash21(cellId + 19.37));
    let point = 1.0 - smoothstep(radius, radius + 0.045, length(cell));
    let speed = mix(0.75, 2.2, hash21(cellId + 7.91));
    let pulse = 0.42 + 0.58 * (0.5 + 0.5 * sin(time * speed + seed * 31.0));
    return point * step(threshold, seed) * pulse;
}
fn marsGeology(p: vec2f) -> vec3f {
    let warpA = geologyFbm(p * vec2f(0.52, 0.78) + vec2f(0.31, 0.17));
    let warpB = geologyPartial(p * vec2f(0.95, 0.42) + vec2f(-0.24, 0.48));
    let warped = p + vec2f((warpA - 0.5) * 0.42, (warpB - 0.5) * 0.24);
    let broadField = geologyFbm(warped * vec2f(0.78, 0.56) + vec2f(0.04, 0.27));
    let mesoField = geologyPartial(warped * vec2f(1.85, 1.05) + vec2f(0.52, -0.19));
    let ridge = 1.0 - abs(2.0 * geologyFbm(warped * vec2f(2.7, 1.5) + vec2f(-0.2, 0.71)) - 1.0);
    let strata = 0.5 + 0.5 * sin(warped.y * 8.0 + broadField * 7.0 + mesoField * 2.0 + warped.x * 1.8);
    return vec3f(broadField * 0.58 + mesoField * 0.42, ridge, strata);
}
fn partialFbm(uv: vec2f) -> f32 {
    return (noiseAt(uv) + noiseAt(uv * 2.0) * 0.5 + noiseAt(uv * 4.01) * 0.25) * 0.5714;
}
fn fbm(uv: vec2f) -> f32 {
    return (noiseAt(uv) + noiseAt(uv * 2.0) * 0.5 + noiseAt(uv * 4.01) * 0.25 + noiseAt(uv * 8.0) * 0.125 + noiseAt(uv * 16.0) * 0.0625) * 0.533333;
}
fn terrainHeight(x: f32) -> f32 {
    let f = fbm(vec2f(x * 0.0125, 0.0));
    return f * f;
}
fn surfaceDistance(p: vec2f) -> f32 { return p.y - terrainHeight(p.x); }
fn visualTerrainHeight(x: f32) -> f32 {
    let e = 0.006;
    return terrainHeight(x - e * 2.0) * 0.08 + terrainHeight(x - e) * 0.22 + terrainHeight(x) * 0.4 + terrainHeight(x + e) * 0.22 + terrainHeight(x + e * 2.0) * 0.08;
}
fn visualSurfaceDistance(p: vec2f) -> f32 { return p.y - visualTerrainHeight(p.x); }
fn surfaceNormal(p: vec2f) -> vec2f {
    let e = 0.005;
    return normalize(vec2f(surfaceDistance(p + vec2f(e, 0.0)) - surfaceDistance(p - vec2f(e, 0.0)), surfaceDistance(p + vec2f(0.0, e)) - surfaceDistance(p - vec2f(0.0, e))));
}
fn positiveMod(value: f32, divisor: f32) -> f32 { return value - divisor * floor(value / divisor); }
fn padColor(p: vec2f) -> vec3f {
    let band = positiveMod(p.y * 12.0, 4.0);
    if band < 0.5 { return vec3f(0.79, 0.65, 0.8); }
    if band < 1.5 { return vec3f(0.91, 0.77, 0.52); }
    if band < 2.5 { return vec3f(0.57, 0.75, 0.86); }
    if band < 3.5 { return vec3f(0.61, 0.81, 0.67); }
    return vec3f(0.9, 0.61, 0.53);
}
fn glyphRow(code: u32, row: u32) -> u32 {
    if code == 32u { return 0u; }
    switch code {
        case 33u: { return array<u32,7>(4u,4u,4u,4u,4u,0u,4u)[row]; }
        case 45u: { return array<u32,7>(0u,0u,0u,31u,0u,0u,0u)[row]; }
        case 46u: { return array<u32,7>(0u,0u,0u,0u,0u,0u,4u)[row]; }
        case 48u: { return array<u32,7>(14u,17u,19u,21u,25u,17u,14u)[row]; }
        case 49u: { return array<u32,7>(4u,12u,4u,4u,4u,4u,14u)[row]; }
        case 50u: { return array<u32,7>(14u,17u,1u,2u,4u,8u,31u)[row]; }
        case 51u: { return array<u32,7>(30u,1u,1u,14u,1u,1u,30u)[row]; }
        case 52u: { return array<u32,7>(2u,6u,10u,18u,31u,2u,2u)[row]; }
        case 53u: { return array<u32,7>(31u,16u,16u,30u,1u,1u,30u)[row]; }
        case 54u: { return array<u32,7>(14u,16u,16u,30u,17u,17u,14u)[row]; }
        case 55u: { return array<u32,7>(31u,1u,2u,4u,8u,8u,8u)[row]; }
        case 56u: { return array<u32,7>(14u,17u,17u,14u,17u,17u,14u)[row]; }
        case 57u: { return array<u32,7>(14u,17u,17u,15u,1u,1u,14u)[row]; }
        case 58u: { return array<u32,7>(0u,4u,0u,0u,4u,0u,0u)[row]; }
        case 65u: { return array<u32,7>(14u,17u,17u,31u,17u,17u,17u)[row]; }
        case 66u: { return array<u32,7>(30u,17u,17u,30u,17u,17u,30u)[row]; }
        case 67u: { return array<u32,7>(14u,17u,16u,16u,16u,17u,14u)[row]; }
        case 68u: { return array<u32,7>(30u,17u,17u,17u,17u,17u,30u)[row]; }
        case 69u: { return array<u32,7>(31u,16u,16u,30u,16u,16u,31u)[row]; }
        case 70u: { return array<u32,7>(31u,16u,16u,30u,16u,16u,16u)[row]; }
        case 71u: { return array<u32,7>(14u,17u,16u,23u,17u,17u,15u)[row]; }
        case 72u: { return array<u32,7>(17u,17u,17u,31u,17u,17u,17u)[row]; }
        case 73u: { return array<u32,7>(14u,4u,4u,4u,4u,4u,14u)[row]; }
        case 74u: { return array<u32,7>(7u,2u,2u,2u,2u,18u,12u)[row]; }
        case 75u: { return array<u32,7>(17u,18u,20u,24u,20u,18u,17u)[row]; }
        case 76u: { return array<u32,7>(16u,16u,16u,16u,16u,16u,31u)[row]; }
        case 77u: { return array<u32,7>(17u,27u,21u,21u,17u,17u,17u)[row]; }
        case 78u: { return array<u32,7>(17u,25u,21u,19u,17u,17u,17u)[row]; }
        case 79u: { return array<u32,7>(14u,17u,17u,17u,17u,17u,14u)[row]; }
        case 80u: { return array<u32,7>(30u,17u,17u,30u,16u,16u,16u)[row]; }
        case 81u: { return array<u32,7>(14u,17u,17u,17u,21u,18u,13u)[row]; }
        case 82u: { return array<u32,7>(30u,17u,17u,30u,20u,18u,17u)[row]; }
        case 83u: { return array<u32,7>(15u,16u,16u,14u,1u,1u,30u)[row]; }
        case 84u: { return array<u32,7>(31u,4u,4u,4u,4u,4u,4u)[row]; }
        case 85u: { return array<u32,7>(17u,17u,17u,17u,17u,17u,14u)[row]; }
        case 86u: { return array<u32,7>(17u,17u,17u,17u,17u,10u,4u)[row]; }
        case 87u: { return array<u32,7>(17u,17u,17u,21u,21u,21u,10u)[row]; }
        case 88u: { return array<u32,7>(17u,17u,10u,4u,10u,17u,17u)[row]; }
        case 89u: { return array<u32,7>(17u,17u,10u,4u,4u,4u,4u)[row]; }
        case 90u: { return array<u32,7>(31u,1u,2u,4u,8u,16u,31u)[row]; }
        default: { return 0u; }
  }
}
fn textLength(label: u32) -> u32 {
    return array<u32,20>(12u,19u,10u,11u,8u,18u,14u,29u,10u,21u,5u,4u,3u,5u,5u,4u,13u,8u,9u,8u)[label];
}
fn textCode(label: u32, index: u32) -> u32 {
    switch label {
        case 0u: { return TITLE[index]; } case 1u: { return PLAY[index]; }
        case 2u: { return START[index]; } case 3u: { return HOWTO[index]; }
        case 4u: { return CONTROLS[index]; } case 5u: { return ROTATE[index]; }
        case 6u: { return BOOST[index]; } case 7u: { return LAND[index]; }
        case 8u: { return PADVALUES[index]; } case 9u: { return RETURN_TEXT[index]; }
        case 10u: { return SCORE[index]; } case 11u: { return FUEL[index]; }
        case 12u: { return ALT[index]; } case 13u: { return HVEL[index]; }
        case 14u: { return VVEL[index]; } case 15u: { return DEAD[index]; }
        case 16u: { return FUEL_LOST[index]; } case 17u: { return SUCCESS[index]; }
        case 18u: { return GAME_OVER[index]; } default: { return LOW_FUEL[index]; }
  }
}
fn textMask(p: vec2f, origin: vec2f, scale: f32, label: u32) -> f32 {
    let local = (p - origin) / scale;
    if local.x < 0.0 || local.y < 0.0 || local.y >= 7.0 { return 0.0; }
    let index = u32(floor(local.x / 6.0));
    if index >= textLength(label) { return 0.0; }
    let cellX = u32(floor(local.x)) % 6u;
    if cellX >= 5u { return 0.0; }
    let row = u32(floor(local.y));
    let bits = glyphRow(textCode(label, index), row);
    return f32((bits >> (4u - cellX)) & 1u);
}
fn numberDigit(value: i32, place: i32) -> u32 {
    let divisor = i32(pow(10.0, f32(place)));
    return u32(abs(value) / divisor % 10) + 48u;
}
fn numberMask(p: vec2f, origin: vec2f, scale: f32, value: i32, digits: u32) -> f32 {
    let local = (p - origin) / scale;
    if local.x < 0.0 || local.y < 0.0 || local.y >= 7.0 { return 0.0; }
    let index = u32(floor(local.x / 6.0));
    if index >= digits { return 0.0; }
    let cellX = u32(floor(local.x)) % 6u;
    if cellX >= 5u { return 0.0; }
    let row = u32(floor(local.y));
    let place = i32(digits - 1u - index);
    return f32((glyphRow(numberDigit(value, place), row) >> (4u - cellX)) & 1u);
}
fn lineDistance(p: vec2f, a: vec2f, b: vec2f) -> f32 {
    let pa = p - a;
    let ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}
fn boxDistance(p: vec2f, halfSize: vec2f) -> f32 {
    let d = abs(p) - halfSize;
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0);
}
fn boxFrame(p: vec2f, center: vec2f, halfSize: vec2f, thickness: f32) -> f32 {
    let outer = 1.0 - smoothstep(-0.5, 0.5, boxDistance(p - center, halfSize));
    let inner = 1.0 - smoothstep(-0.5, 0.5, boxDistance(p - center, max(halfSize - vec2f(thickness), vec2f(0.0))));
    return clamp(outer - inner, 0.0, 1.0);
}
fn roundedBoxDistance(p: vec2f, halfSize: vec2f, radius: f32) -> f32 {
    let q = abs(p) - halfSize + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2f(0.0))) - radius;
}
fn crispFill(distance: f32) -> f32 {
    let aa = max(fwidth(distance), 0.003);
    return 1.0 - smoothstep(-aa, aa, distance);
}
fn rotatePoint(p: vec2f, angle: f32) -> vec2f {
    let c = cos(angle);
    let s = sin(angle);
    return mat2x2f(c, -s, s, c) * p;
}
fn shipMask(world: vec2f) -> vec3f {
    let angle = game.ship.z - 6.28318530718 * floor(game.ship.z / 6.28318530718);
    let c = cos(angle);
    let s = sin(angle);
    let rot = mat2x2f(c, -s, s, c);
    let p = rot * (world - game.motion.xy) / 0.0125;
    let crashed = i32(round(game.status.x)) == 5;
    let age = select(0.0, clamp(frame.resolutionTime.z - game.status.z, 0.0, 4.0), crashed);
    let cabinP = rotatePoint(p - vec2f(0.0, age * 0.28), age * 0.8);
    let hullP = rotatePoint(p - vec2f(-age * 0.22, age * 0.08), -age * 1.15);
    let engineP = rotatePoint(p - vec2f(age * 0.18, -age * 0.48), age * 1.7);
    let leftP = rotatePoint(p - vec2f(-age * 0.52, -age * 0.22), -age * 2.1);
    let rightP = rotatePoint(p - vec2f(age * 0.52, -age * 0.22), age * 2.3);
    let cabinD = length((cabinP - vec2f(0.0, 0.34)) * vec2f(1.04, 1.28)) - 0.34;
    let hullD = roundedBoxDistance(hullP - vec2f(0.0, 0.01), vec2f(0.36, 0.19), 0.075);
    let skirtD = roundedBoxDistance(engineP - vec2f(0.0, -0.22), vec2f(0.24, 0.075), 0.03);
    let leftTankD = roundedBoxDistance(leftP - vec2f(-0.4, 0.02), vec2f(0.085, 0.16), 0.035);
    let rightTankD = roundedBoxDistance(rightP - vec2f(0.4, 0.02), vec2f(0.085, 0.16), 0.035);
    let leftLegD = min(lineDistance(leftP, vec2f(-0.24, -0.1), vec2f(-0.5, -0.45)), lineDistance(leftP, vec2f(-0.66, -0.45), vec2f(-0.4, -0.45))) - 0.022;
    let rightLegD = min(lineDistance(rightP, vec2f(0.24, -0.1), vec2f(0.5, -0.45)), lineDistance(rightP, vec2f(0.4, -0.45), vec2f(0.66, -0.45))) - 0.022;
    let silhouetteD = min(min(cabinD, hullD), min(skirtD, min(min(leftTankD, rightTankD), min(leftLegD, rightLegD))));
    let silhouette = crispFill(silhouetteD);
    let outline = clamp(crispFill(silhouetteD + 0.04) - silhouette, 0.0, 1.0);
    let cabin = crispFill(cabinD);
    let hull = crispFill(hullD);
    let skirt = crispFill(skirtD);
    let tanks = crispFill(min(leftTankD, rightTankD));
    let legs = crispFill(min(leftLegD, rightLegD));
    let windowD = length((cabinP - vec2f(0.0, 0.34)) * vec2f(1.02, 1.25)) - 0.17;
    let window = crispFill(windowD);
    let panelD = roundedBoxDistance(hullP - vec2f(0.17, 0.035), vec2f(0.075, 0.06), 0.018);
    let panel = crispFill(panelD);
    let portD = min(length(hullP - vec2f(-0.24, 0.07)), length(hullP - vec2f(0.24, 0.07))) - 0.032;
    let ports = crispFill(portD);
    let antennaD = min(lineDistance(cabinP, vec2f(0.0, 0.61), vec2f(0.0, 0.78)) - 0.014, length(cabinP - vec2f(0.0, 0.81)) - 0.038);
    let antenna = crispFill(antennaD);
    var color = outline * vec3f(0.25, 0.16, 0.23) + hull * vec3f(0.78, 0.48, 0.45) + skirt * vec3f(0.57, 0.3, 0.32);
    color           += tanks * vec3f(0.68, 0.4, 0.42) + cabin * vec3f(0.93, 0.7, 0.58);
    color           += legs * vec3f(0.67, 0.58, 0.67) + antenna * vec3f(0.95, 0.78, 0.65);
    color           += panel * vec3f(0.95, 0.66, 0.5) + ports * vec3f(0.52, 0.7, 0.69);
    color = mix(color, vec3f(0.43, 0.66, 0.68), window);
    if game.ship.w > 0.5 && !crashed {
        let flicker = 0.88 + 0.08 * sin(frame.resolutionTime.z * 11.0);
        let flameOuterD = lineDistance(p, vec2f(0.0, -0.28), vec2f(0.0, -0.86 * flicker)) - mix(0.12, 0.008, clamp((-p.y - 0.28) / 0.58, 0.0, 1.0));
        let flameInnerD = lineDistance(p, vec2f(0.0, -0.3), vec2f(0.0, -0.66 * flicker)) - mix(0.055, 0.004, clamp((-p.y - 0.3) / 0.38, 0.0, 1.0));
        color           += crispFill(flameOuterD) * vec3f(0.95, 0.56, 0.39);
        color           += crispFill(flameInnerD) * vec3f(1.0, 0.84, 0.58);
    }
    return color;
}
fn impactEffect(world: vec2f) -> vec3f {
    if i32(round(game.status.x)) != 5 { return vec3f(0.0); }
    let age = clamp(frame.resolutionTime.z - game.status.z, 0.0, 1.0);
    let contact = vec2f(game.motion.x, game.motion.y - surfaceDistance(game.motion.xy));
    let q = (world - contact) / 0.0125;
    var debris = 0.0;
    var spokes = 0.0;
    for (var i = 0u; i < 9u; i++) {
        let fi = f32(i);
        let angle = 0.25 + fi * 0.34;
        let direction = vec2f(cos(angle), sin(angle));
        let speed = 1.1 + f32(i % 3u) * 0.32;
        let particle = direction * age * speed + vec2f(0.0, -age * age * 0.34);
        debris = max(debris, crispFill(length(q - particle) - (0.025 + f32(i % 2u) * 0.012)));
        let rayEnd = direction * min(age * 5.5, 1.0 + speed * 0.18);
        spokes = max(spokes, crispFill(lineDistance(q, vec2f(0.0), rayEnd) - 0.015));
    }
    let burst = 1.0 - smoothstep(0.045, 0.16, age);
    let dust = debris * (1.0 - smoothstep(0.45, 1.0, age));
    return spokes * burst * vec3f(1.0, 0.88, 0.69) + dust * vec3f(0.84, 0.58, 0.43);
}
fn addText(color: vec3f, p: vec2f, origin: vec2f, scale: f32, label: u32, tint: vec3f) -> vec3f {
    return mix(color, tint, textMask(p, origin, scale, label));
}
@fragment
fn fragmentMain(@builtin(position) position: vec4f) -> @location(0) vec4f {
    let resolution = frame.resolutionTime.xy;
    let uv = position.xy / resolution;
    let pixel = uv * vec2f(320.0, 180.0);
    let state = i32(round(game.status.x));
    let time = frame.resolutionTime.z;
    let ink = vec3f(0.96, 0.88, 0.8);
    let dim = vec3f(0.68, 0.58, 0.7);
    let accent = vec3f(0.94, 0.66, 0.62);
    var camera = vec2f(time * 0.012, 0.54);
    var zoom = 1.0;
    if state >= 4 && state <= 7 { camera = game.camera.xy; zoom = game.status.w; }
    var ndc = vec2f((uv.x * 2.0 - 1.0) * resolution.x / resolution.y, 1.0 - uv.y * 2.0);
    var impactAge = 1.0;
    if state == 5 {
        impactAge = clamp(time - game.status.z, 0.0, 1.0);
        let kick = (1.0 - smoothstep(0.0, 0.22, impactAge)) * 0.008;
        ndc           += vec2f(sin(time * 137.0), cos(time * 173.0)) * kick;
    }
    let world = ndc / zoom + camera;
    let distance = surfaceDistance(world);
    let visualDistance = visualSurfaceDistance(world);
    var color = mix(vec3f(0.075, 0.075, 0.16), vec3f(0.39, 0.2, 0.29), pow(uv.y, 1.65));
    let skyWash = geologyPartial(uv * vec2f(1.25, 0.72) + vec2f(0.17, 0.41));
    color = mix(color, vec3f(0.46, 0.28, 0.38), smoothstep(0.54, 0.82, skyWash) * 0.13);
    let starsFine = starLayer(uv, time, vec2f(132.0, 74.0), 0.976);
    let starsBright = starLayer(uv + vec2f(0.003, 0.007), time, vec2f(73.0, 41.0), 0.986);
    color           += starsFine * vec3f(0.86, 0.82, 0.96) * 0.72;
    color           += starsBright * vec3f(1.0, 0.83, 0.72);
    let planetP = (uv - vec2f(0.79, 0.2)) * vec2f(resolution.x / resolution.y, 1.0);
    let planetRadius = 0.058;
    let planetLocal = planetP / planetRadius;
    let planetR = length(planetLocal);
    let planetDisk = 1.0 - smoothstep(0.97, 1.0, planetR);
    let planetZ = sqrt(max(0.0, 1.0 - planetR * planetR));
    let sphereNormal = normalize(vec3f(planetLocal, planetZ));
    let light = 0.3 + 0.7 * max(dot(sphereNormal, normalize(vec3f(-0.55, -0.38, 0.92))), 0.0);
    let planetAngle = time * 0.012;
    let planetRotation = mat2x2f(cos(planetAngle), -sin(planetAngle), sin(planetAngle), cos(planetAngle));
    let planetTexture = planetRotation * planetLocal;
    let continentWarp = geologyPartial(planetTexture * vec2f(1.4, 1.05) + vec2f(0.31, 0.57));
    let landNoise = geologyFbm(planetTexture * vec2f(2.15, 1.45) + vec2f(0.42, -0.24) + vec2f((continentWarp - 0.5) * 0.32, (continentWarp - 0.5) * 0.16));
    let landDetail = geologyPartial(planetTexture * vec2f(4.1, 2.6) + vec2f(-0.72, 0.18));
    let land = smoothstep(0.47, 0.59, landNoise * 0.78 + landDetail * 0.22 + sin(planetTexture.y * 4.2) * 0.035);
    let oceanColor = vec3f(0.3, 0.23, 0.32);
    let landColor = vec3f(0.72, 0.48, 0.4);
    var planetColor = mix(oceanColor, landColor, land) * (0.68 + light * 0.32);
    let cloudNoise = geologyPartial(planetTexture * vec2f(3.2, 1.45) + vec2f(-0.42, 0.16));
    let clouds = smoothstep(0.64, 0.77, cloudNoise + sin(planetTexture.y * 7.0 + planetTexture.x * 1.8) * 0.045) * planetDisk * 0.27;
    planetColor = mix(planetColor, vec3f(0.9, 0.7, 0.6), clouds);
    let atmosphereOuter = (1.0 - smoothstep(planetRadius * 1.0, planetRadius * 1.13, length(planetP))) * (1.0 - planetDisk);
    let atmosphereInner = smoothstep(0.82, 0.99, planetR) * planetDisk;
    let atmosphere = max(atmosphereOuter, atmosphereInner * 0.86);
    color = mix(color, vec3f(0.92, 0.62, 0.64), atmosphere * 0.52);
    color = mix(color, planetColor, planetDisk * 0.82);
    let geology = marsGeology(world);
    let depth = clamp(-visualDistance * 1.15, 0.0, 1.0);
    var mars = mix(vec3f(0.38, 0.2, 0.22), vec3f(0.84, 0.49, 0.42), smoothstep(0.18, 0.8, geology.x));
    mars = mix(mars, vec3f(0.95, 0.66, 0.53), geology.y * 0.2);
    mars = mix(mars, vec3f(0.27, 0.14, 0.17), smoothstep(0.0, 0.28, 1.0 - geology.y) * 0.24);
    mars = mix(mars, vec3f(0.72, 0.37, 0.35), geology.z * 0.15);
    mars = mix(mars, vec3f(0.3, 0.18, 0.24), depth * 0.26);
    let terrainFill = 1.0 - smoothstep(-0.0035, 0.0015, visualDistance);
    color = mix(color, mars, terrainFill);
    let normal = surfaceNormal(world);
    let shelf = smoothstep(0.925, 0.94, dot(normal, vec2f(0.0, 1.0)));
    let edge = 1.0 - smoothstep(0.0008, 0.0032, abs(visualDistance));
    let naturalEdge = vec3f(0.94, 0.68, 0.62);
    color = mix(color, mix(naturalEdge, padColor(world), shelf * 0.74), edge * 0.68);
    if state >= 4 && state <= 7 {
        color           += shipMask(world);
        color           += impactEffect(world);
        let leftCenter = vec2f(34.0, 14.0);
        let rightCenter = vec2f(292.0, 11.0);
        let leftHalf = vec2f(29.0, 10.0);
        let rightHalf = vec2f(23.0, 7.0);
        let leftCard = 1.0 - smoothstep(0.0, 0.8, boxDistance(pixel - leftCenter, leftHalf));
        let rightCard = 1.0 - smoothstep(0.0, 0.8, boxDistance(pixel - rightCenter, rightHalf));
        color = mix(color, vec3f(0.12, 0.085, 0.17), leftCard * 0.46);
        color = mix(color, vec3f(0.12, 0.085, 0.17), rightCard * 0.46);
        color           += boxFrame(pixel, leftCenter, leftHalf, 0.85) * vec3f(0.45, 0.32, 0.47) * 0.55;
        color           += boxFrame(pixel, rightCenter, rightHalf, 0.85) * vec3f(0.45, 0.32, 0.47) * 0.55;
        color = addText(color, pixel, vec2f(10.0, 8.0), 0.52, 10u, dim);
        color = addText(color, pixel, vec2f(10.0, 15.0), 0.52, 11u, dim);
        color = addText(color, pixel, vec2f(276.0, 8.0), 0.52, 12u, dim);
        color = mix(color, ink, numberMask(pixel, vec2f(29.0, 8.0), 0.52, i32(game.ship.y * 5000.0), 6u));
        color = mix(color, ink, numberMask(pixel, vec2f(26.0, 15.0), 0.52, i32(game.ship.x), 3u));
        color = mix(color, ink, numberMask(pixel, vec2f(288.0, 8.0), 0.52, i32(max(distance * 400.0, 0.0)), 3u));
        if game.ship.x < 100.0 && state == 4 { color = addText(color, pixel, vec2f(142.0, 8.0), 0.7, 19u, vec3f(1.0, 0.55, 0.24)); }
        if state == 5 {
            color = addText(color, pixel, vec2f(150.0, 132.0), 0.9, 15u, vec3f(1.0, 0.42, 0.2));
            color = addText(color, pixel, vec2f(134.0, 143.0), 0.65, 16u, dim);
        }
        if state == 7 { color = addText(color, pixel, vec2f(138.0, 132.0), 0.9, 17u, accent); }
    } else if state == 0 {
        color = addText(color, pixel, vec2f(18.0, 22.0), 1.0, 0u, ink);
        color = addText(color, pixel, vec2f(18.0, 34.0), 0.58, 1u, mix(dim, accent, 0.65 + 0.35 * sin(time * 2.2)));
    } else if state == 1 {
        color = addText(color, pixel, vec2f(18.0, 22.0), 0.9, 0u, ink);
        let selected = u32(round(game.status.y));
        let startCenter = vec2f(42.0, 50.5);
        let howCenter = vec2f(43.0, 60.5);
        let startHalf = vec2f(27.0, 6.0);
        let howHalf = vec2f(30.0, 6.0);
        let startPanel = 1.0 - smoothstep(0.0, 0.7, boxDistance(pixel - startCenter, startHalf));
        let howPanel = 1.0 - smoothstep(0.0, 0.7, boxDistance(pixel - howCenter, howHalf));
        let selectedPanel = select(howPanel, startPanel, selected == 0u);
        color = mix(color, vec3f(0.13, 0.09, 0.17), selectedPanel * 0.62);
        color = addText(color, pixel, vec2f(19.0, 48.0), 0.7, 2u, select(dim, accent, selected == 0u));
        color = addText(color, pixel, vec2f(19.0, 58.0), 0.7, 3u, select(dim, accent, selected == 1u));
        color           += boxFrame(pixel, startCenter, startHalf, 0.9) * select(0.0, 1.0, selected == 0u) * accent * 0.9;
        color           += boxFrame(pixel, howCenter, howHalf, 0.9) * select(0.0, 1.0, selected == 1u) * accent * 0.9;
    } else if state == 2 {
        let panel = 1.0 - smoothstep(0.0, 2.0, boxDistance(pixel - vec2f(95.0, 70.0), vec2f(78.0, 54.0)));
        color = mix(color, vec3f(0.08, 0.025, 0.027), panel * 0.86);
        color           += boxFrame(pixel, vec2f(95.0, 70.0), vec2f(78.0, 54.0), 0.9) * vec3f(0.58, 0.4, 0.5) * 0.55;
        color = addText(color, pixel, vec2f(21.0, 24.0), 0.9, 4u, ink);
        color = addText(color, pixel, vec2f(21.0, 43.0), 0.65, 5u, dim);
        color = addText(color, pixel, vec2f(21.0, 53.0), 0.65, 6u, dim);
        color = addText(color, pixel, vec2f(21.0, 76.0), 0.58, 7u, dim);
        color = addText(color, pixel, vec2f(21.0, 98.0), 0.7, 8u, ink);
        color = addText(color, pixel, vec2f(21.0, 126.0), 0.62, 9u, accent);
        let pads = array<vec3f,5>(vec3f(0.18,0.46,1.0),vec3f(0.98,0.8,0.14),vec3f(0.12,0.95,0.45),vec3f(0.97,0.08,0.78),vec3f(1.0,0.25,0.08));
        for (var i = 0u; i < 5u; i++) {
            let box = 1.0 - smoothstep(0.0, 0.7, boxDistance(pixel - vec2f(25.0 + f32(i) * 18.0, 113.0), vec2f(1.7)));
            color = mix(color, pads[i], box);
        }
    } else if state == 8 {
        color = addText(color, pixel, vec2f(18.0, 24.0), 1.0, 18u, vec3f(1.0, 0.43, 0.2));
        color = addText(color, pixel, vec2f(19.0, 39.0), 0.58, 1u, dim);
    }
    let vignette = smoothstep(0.86, 0.3, length(uv - 0.5));
    color           *= 0.9 + 0.1 * vignette;
    color           += (noiseAt(position.xy / 410.0) - 0.5) * 0.0007;
    if state == 5 { color           += vec3f(0.86, 0.67, 0.52) * (1.0 - smoothstep(0.0, 0.055, impactAge)) * 0.32; }
    return vec4f(pow(max(color, vec3f(0.0)), vec3f(0.96)), 1.0);
}
