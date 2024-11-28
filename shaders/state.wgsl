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
@group(0) @binding(0) var<uniform> frame: Frame;
@group(0) @binding(1) var<storage, read_write> game: GameState;
@group(0) @binding(2) var noiseTexture: texture_2d<f32>;
@group(0) @binding(3) var noiseSampler: sampler;
const LEFT: u32 = 1u;
const RIGHT: u32 = 2u;
const UP_KEY: u32 = 4u;
const DOWN_KEY: u32 = 8u;
const THRUST: u32 = 16u;
const ENTER: u32 = 32u;
const ESCAPE: u32 = 64u;
fn held(key: u32) -> bool { return (frame.input.x & key) != 0u; }
fn tapped(key: u32) -> bool { return (frame.input.y & key) != 0u; }
fn noiseAt(uv: vec2f) -> f32 { return textureSampleLevel(noiseTexture, noiseSampler, uv, 0.0).r; }
fn partialFbm(uv: vec2f) -> f32 {
    var result = noiseAt(uv);
    result     += noiseAt(uv * 2.0) * 0.5;
    result     += noiseAt(uv * 4.01) * 0.25;
    return result * 0.5714;
}
fn fbm(uv: vec2f) -> f32 {
    var result = noiseAt(uv);
    result     += noiseAt(uv * 2.0) * 0.5;
    result     += noiseAt(uv * 4.01) * 0.25;
    result     += noiseAt(uv * 8.0) * 0.125;
    result     += noiseAt(uv * 16.0) * 0.0625;
    return result * 0.533333;
}
fn terrainHeight(x: f32) -> f32 {
    let f = fbm(vec2f(x * 0.0125, 0.0));
    return f * f;
}
fn surfaceDistance(p: vec2f) -> f32 { return p.y - terrainHeight(p.x); }
fn softSurfaceDistance(p: vec2f) -> f32 {
    let f = partialFbm(vec2f(p.x * 0.0125, 0.0));
    return p.y - f * f;
}
fn surfaceNormal(p: vec2f) -> vec2f {
    let e = 0.005;
    return normalize(vec2f(surfaceDistance(p + vec2f(e, 0.0)) - surfaceDistance(p - vec2f(e, 0.0)), surfaceDistance(p + vec2f(0.0, e)) - surfaceDistance(p - vec2f(0.0, e))));
}
fn positiveMod(value: f32, divisor: f32) -> f32 { return value - divisor * floor(value / divisor); }
fn padValue(p: vec2f) -> f32 {
    let band = positiveMod(p.y * 12.0, 4.0);
    if band < 0.5 { return 6.0; }
    if band < 1.5 { return 2.0; }
    if band < 2.5 { return 1.0; }
    if band < 3.5 { return 4.0; }
    return 8.0;
}
fn randomSigned(seed: f32) -> f32 { return fract(sin(seed * 1230.114) * 43758.5453) * 2.0 - 1.0; }
@compute @workgroup_size(1)
fn update() {
    let time = frame.resolutionTime.z;
    let dtScale = frame.resolutionTime.w * 60.0;
    var state = i32(round(game.status.x));
    if frame.input.z == 0u {
        game.motion = vec4f(0.0);
        game.ship = vec4f(0.0);
        game.status = vec4f(0.0, 0.0, time, 1.0);
        game.camera = vec4f(0.0);
        return;
    }
    if state == 0 {
        if tapped(ENTER) { game.status.x = 1.0; }
        return;
    }
    if state == 1 {
        if tapped(UP_KEY) || tapped(DOWN_KEY) { game.status.y = 1.0 - game.status.y; }
        if tapped(ENTER) {
            game.status.x = select(3.0, 2.0, game.status.y > 0.5);
            game.status.z = time;
        }
        return;
    }
    if state == 2 {
        if tapped(ENTER) {
            game.status.x = 1.0;
            game.status.z = time;
        }
        return;
    }
    if state == 3 {
        let r = randomSigned(time + f32(frame.input.z) * 0.01);
        game.motion = vec4f(20.0 * r, 0.8, 0.003 * r, 0.0);
        if game.ship.x < 0.001 { game.ship = vec4f(800.0, 0.0, 0.0, 0.0); } else {
            game.ship.z = 0.0;
            game.ship.w = 0.0;
        }
        game.camera = vec4f(game.motion.xy, 0.0, 0.0);
        game.status = vec4f(4.0, game.status.y, time, 1.0);
        return;
    }
    if state == 4 {
        if held(ESCAPE) {
            game.status.x = 8.0;
            game.status.z = time;
        }
        game.camera.x = game.motion.x;
        game.camera.y = game.motion.y;
        let e = 0.005;
        let smoothDelta = softSurfaceDistance(game.motion.xy + vec2f(e, 0.0)) - softSurfaceDistance(game.motion.xy - vec2f(e, 0.0)) / 2.0 * e;
        game.status.w = clamp(0.5 / smoothDelta, 1.25, 4.0);
        let distance = surfaceDistance(game.motion.xy);
        if distance <= 0.0065 {
            let normal = surfaceNormal(game.motion.xy);
            let facing = vec2f(-sin(game.ship.z), cos(game.ship.z));
            let aligned = dot(normal, facing) > 0.975 && dot(vec2f(0.0, 1.0), facing) > 0.925;
            if length(game.motion.zw) < 0.003 && aligned {
                let contact = vec2f(game.motion.x, game.motion.y - distance);
                game.ship.y     += dot(normal, facing) * dot(normal, facing) * padValue(contact);
                game.status.x = 7.0;
            } else {
                game.ship.x = max(0.0, game.ship.x - 100.0);
                game.status.x = 5.0;
            }
            game.status.z = time;
        }
        game.motion.w     -= 0.000002 * dtScale;
        if held(LEFT) { game.ship.z     += 0.08 * dtScale; }
        if held(RIGHT) { game.ship.z     -= 0.08 * dtScale; }
        game.ship.w = 0.0;
        if held(THRUST) && game.ship.x >= 0.05 {
            game.ship.x     -= 0.05 * dtScale;
            game.ship.w = 1.0;
            let boost = vec2f(-sin(game.ship.z), cos(game.ship.z)) * 0.000007 * dtScale;
            game.motion.z     += boost.x;
            game.motion.w     += boost.y;
        }
        game.motion.x     += game.motion.z;
        game.motion.y     += game.motion.w;
        return;
    }
    if state == 5 || state == 7 {
        if tapped(ENTER) || time - game.status.z >= 4.0 {
            game.status.x = select(8.0, 3.0, game.ship.x >= 0.05);
            game.status.z = time;
        }
        return;
    }
    if state == 8 && tapped(ENTER) {
        game.motion = vec4f(0.0);
        game.ship = vec4f(0.0);
        game.status = vec4f(0.0, 0.0, time, 1.0);
    }
}
