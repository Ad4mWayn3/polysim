const root = @import("polysim");
const Polygon2D = @import("Polygon2D");
const Sim = @import("Sim");
const std = root.std;
const rl = root.rl;
const rlgl = rl.gl;
const rgui = root.rgui;

const tau = std.math.tau;

var sim: Sim = undefined;

pub fn main(init: std.process.Init) !void {
    // initialize window
    rl.setTraceLogLevel(.warning);
    rl.setExitKey(.null);
    const screen = .{
        .width = @divTrunc(rl.getScreenWidth()*3, 4),
        .height = @divTrunc(rl.getScreenHeight()*3, 4), };
    _ = screen;
    rl.initWindow(1200,600, "polysim!!");
    defer rl.closeWindow();

    // seed the pseudo-RNG and initialize the simulator
    var seed: [64/8]u8 = undefined;
    init.io.random(&seed);
    const random = @constCast(&std.Random.DefaultPrng.init(@bitCast(seed))).random();
    try sim.init(random, init.gpa, init.io);

    while (!rl.windowShouldClose()) {
        // var update = init.io.async(Sim.update, .{&sim, rl.getFrameTime()});
        // defer update.await(init.io) catch unreachable;

        rl.beginDrawing();
        rl.clearBackground(.black);
        //const simcopy = sim;
        var draw = init.io.async(Sim.draw, .{sim});
        try sim.update(rl.getFrameTime());
        draw.await(init.io);
        //sim.draw();
        rl.drawFPS(30,30);
        rl.endDrawing();
    }
}

const vertex =
\\#version 330 core
\\layout (location = 0) in vec2 pos;
\\layout (location = 1) in vec3 color;
\\out vec3 outColor;
\\void main() {
\\  gl_Position = vec4(pos,0.,1.);
\\  outColor = color;
\\}
;

const fragment =
\\#version 330 core
\\in vec3 outColor;
\\out vec4 fragColor;
\\void main() {
\\  fragColor = vec4(outColor,1.);
\\}
;

var vertices: [2*7]f32 = undefined;

const colors = [_]f32{
    1,1,1,
    1,0,0,
    1,1,0,
    0,1,0,
    0,1,1,
    0,0,1,
    1,0,1,
};

const indices = [_]u16{
    0,1,2,
    0,2,3,
    0,3,4,
    0,4,5,
    0,5,6,
    0,6,1,
};

pub fn _main() !void {
    rl.initWindow(600, 600, "rlTriangle!");
    defer rl.closeWindow();

    const vao = rlgl.rlLoadVertexArray();
    if (!rlgl.rlEnableVertexArray(vao)) unreachable;

    vertices[0..2].* = .{0,0};

    for (0..6) |i| {
        const fi: f32 = @floatFromInt(i);
        const theta = fi * tau/6;
        vertices[2 + 2*i] = @cos(theta);
        vertices[2 + 2*i+1] = @sin(theta);
    }

    const vbo = rlgl.rlLoadVertexBuffer(&vertices, @sizeOf(@TypeOf(vertices)),
        false);
    rlgl.rlSetVertexAttribute(0, 2, rlgl.rl_float, false, 0, 0);
    rlgl.rlEnableVertexAttribute(0);
    defer rlgl.rlUnloadVertexBuffer(vbo);

    const colorBO = rlgl.rlLoadVertexBuffer(&colors, @sizeOf(@TypeOf(colors)),
        false);
    rlgl.rlSetVertexAttribute(1, 3, rlgl.rl_float, false, 0, 0);
    rlgl.rlEnableVertexAttribute(1);
    defer rlgl.rlUnloadVertexBuffer(colorBO);

    const ebo = rlgl.rlLoadVertexBufferElement(&indices, @sizeOf(@TypeOf(indices)),
        false);
    defer rlgl.rlUnloadVertexBuffer(ebo);

    const shader = try rl.loadShaderFromMemory(vertex, fragment);
    defer rl.unloadShader(shader);

    rlgl.rlDisableVertexArray();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(.black);

        _ = rlgl.rlEnableVertexArray(vao);
        rlgl.rlEnableShader(shader.id);
            //rlgl.rlEnableVertexBufferElement(ebo);
            rlgl.rlDrawVertexArrayElements(0, indices.len, null);
            //rlgl.rlDisableVertexBufferElement();
        rlgl.rlDisableShader();
        rlgl.rlDisableVertexArray();

        rl.endDrawing();
    }
}
