const canvas = document.querySelector("#game");
const status = document.querySelector("#status");
const WIDTH = 1280;
const HEIGHT = 720;
const STATE_BYTES = 64;
const UNIFORM_BYTES = 32;
const KEY = {
    ArrowLeft: 1 << 0,
    ArrowRight: 1 << 1,
    ArrowUp: 1 << 2,
    ArrowDown: 1 << 3,
    Space: 1 << 4,
    Enter: 1 << 5,
    Escape: 1 << 6,
};
let held = 0;
let pressed = 0;
for (const type of ["keydown", "keyup"]) {
    window.addEventListener(type, (event) => {
        const bit = KEY[event.code];
        if (!bit) return;
        event.preventDefault();
        if (type === "keydown") {
            if (!(held & bit)) pressed |= bit;
            held |= bit;
        } else {
            held &= ~bit;
        }
    });
}
async function loadShader(path) {
    const response = await fetch(path);
    if (!response.ok) throw new Error(`Could not load ${path}`);
    return response.text();
}
function shaderModule(device, label, code) {
    const module = device.createShaderModule({ label, code });
    module.getCompilationInfo().then(({ messages }) => {
        for (const message of messages) {
            const method = message.type === "error" ? "error" : "warn";
            console[method](
                `${label}:${message.lineNum}:${message.linePos} ${message.message}`,
            );
        }
    });
    return module;
}
async function loadTexture(device, url) {
    const bitmap = await createImageBitmap(await (await fetch(url)).blob(), {
        colorSpaceConversion: "none",
    });
    const texture = device.createTexture({
        label: "noise texture",
        size: [bitmap.width, bitmap.height],
        format: "rgba8unorm",
        usage:
            GPUTextureUsage.TEXTURE_BINDING |
            GPUTextureUsage.COPY_DST |
            GPUTextureUsage.RENDER_ATTACHMENT,
    });
    device.queue.copyExternalImageToTexture({ source: bitmap }, { texture }, [
        bitmap.width,
        bitmap.height,
    ]);
    return texture;
}
async function start() {
    if (!navigator.gpu)
        throw new Error("WebGPU is not available in this browser.");
    const adapter = await navigator.gpu.requestAdapter({
        powerPreference: "high-performance",
    });
    if (!adapter) throw new Error("No WebGPU adapter was found.");
    const device = await adapter.requestDevice();
    device.lost.then(({ message }) => {
        status.hidden = false;
        status.textContent = `GPU DEVICE LOST · ${message || "RELOAD TO RETRY"}`;
    });
    const context = canvas.getContext("webgpu");
    const format = navigator.gpu.getPreferredCanvasFormat();
    canvas.width = WIDTH;
    canvas.height = HEIGHT;
    context.configure({ device, format, alphaMode: "opaque" });
    const [stateCode, renderCode, noiseTexture] = await Promise.all([
        loadShader("shaders/state.wgsl"),
        loadShader("shaders/render.wgsl"),
        loadTexture(device, "assets/noise.png"),
    ]);
    const uniformBuffer = device.createBuffer({
        label: "frame uniforms",
        size: UNIFORM_BYTES,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    const stateBuffer = device.createBuffer({
        label: "game state",
        size: STATE_BYTES,
        usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });
    const sampler = device.createSampler({
        label: "repeat linear sampler",
        addressModeU: "repeat",
        addressModeV: "repeat",
        magFilter: "linear",
        minFilter: "linear",
    });
    const stateModule = shaderModule(device, "shader/state.wgsl", stateCode);
    const renderModule = shaderModule(device, "shader/render.wgsl", renderCode);
    const computePipeline = device.createComputePipeline({
        label: "game state pipeline",
        layout: "auto",
        compute: { module: stateModule, entryPoint: "update" },
    });
    const renderPipeline = device.createRenderPipeline({
        label: "scene pipeline",
        layout: "auto",
        vertex: { module: renderModule, entryPoint: "vertexMain" },
        fragment: {
            module: renderModule,
            entryPoint: "fragmentMain",
            targets: [{ format }],
        },
        primitive: { topology: "triangle-list" },
    });
    const stateBindGroup = device.createBindGroup({
        layout: computePipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: uniformBuffer } },
            { binding: 1, resource: { buffer: stateBuffer } },
            { binding: 2, resource: noiseTexture.createView() },
            { binding: 3, resource: sampler },
        ],
    });
    const renderBindGroup = device.createBindGroup({
        layout: renderPipeline.getBindGroupLayout(0),
        entries: [
            { binding: 0, resource: { buffer: uniformBuffer } },
            { binding: 1, resource: { buffer: stateBuffer } },
            { binding: 2, resource: noiseTexture.createView() },
            { binding: 3, resource: sampler },
        ],
    });
    const uniformData = new ArrayBuffer(UNIFORM_BYTES);
    const floats = new Float32Array(uniformData);
    const uints = new Uint32Array(uniformData);
    let startTime = performance.now();
    let previous = startTime;
    let frame = 0;
    status.hidden = true;
    function draw(now) {
        const time = (now - startTime) / 1000;
        const delta = (now - previous) / 1000;
        previous = now;
        floats.set([WIDTH, HEIGHT, time, delta], 0);
        uints.set([held, pressed, frame++, 0], 4);
        device.queue.writeBuffer(uniformBuffer, 0, uniformData);
        const encoder = device.createCommandEncoder({
            label: "frame",
        });
        const compute = encoder.beginComputePass({
            label: "update game",
        });
        compute.setPipeline(computePipeline);
        compute.setBindGroup(0, stateBindGroup);
        compute.dispatchWorkgroups(1);
        compute.end();
        const render = encoder.beginRenderPass({
            label: "render scene",
            colorAttachments: [
                {
                    view: context.getCurrentTexture().createView(),
                    clearValue: { r: 0, g: 0, b: 0, a: 1 },
                    loadOp: "clear",
                    storeOp: "store",
                },
            ],
        });
        render.setPipeline(renderPipeline);
        render.setBindGroup(0, renderBindGroup);
        render.draw(3);
        render.end();
        device.queue.submit([encoder.finish()]);
        pressed = 0;
        requestAnimationFrame(draw);
    }
    requestAnimationFrame(draw);
}
start().catch((error) => {
    console.error(error);
    status.textContent = error.message.toUpperCase();
});
