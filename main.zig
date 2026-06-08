const root = @import("polysim");
const Polygon2D = @import("Polygon2D");
const Sim = @import("Sim");
const std = root.std;
const rl = root.rl;
const rgui = root.rgui;

const tau = std.math.tau;

var sim: Sim = undefined;

fn initMesh(vertexBuf: []const f32, indexBuf: []const c_ushort) rl.Mesh {
    var out = std.mem.zeroes(rl.Mesh);
    std.debug.assert(out.vaoId == 0);
    out.vertexCount = @intCast(indexBuf.len);
    out.triangleCount = @intCast(indexBuf.len / 3);
    
    out.vertices = @alignCast(@ptrCast(rl.memAlloc(
        @intCast(@sizeOf(f32) * vertexBuf.len))));
    out.indices = @alignCast(@ptrCast(rl.memAlloc(
        @intCast(@sizeOf(c_ushort) * indexBuf.len))));

    std.mem.copyForwards(f32, out.vertices[0..vertexBuf.len], vertexBuf);
    std.mem.copyForwards(c_ushort, out.indices[0..indexBuf.len], indexBuf);

    out.texcoords = @alignCast(@ptrCast(rl.memAlloc(
        @intCast(@sizeOf(f32) * out.vertexCount * 2))));
    out.normals = @alignCast(@ptrCast(rl.memAlloc(
        @intCast(@sizeOf(f32) * out.vertexCount * 3))));

    for (0..@intCast(out.vertexCount)) |i| {
        out.texcoords[2*i]     = 0;
        out.texcoords[2*i + 1] = 0;

        out.normals[3*i]     = 0;
        out.normals[3*i + 1] = 0;
        out.normals[3*i + 2] = 1; // WATCH OUT: COULD BE -1
    }

    rl.uploadMesh(&out, true);
    return out;
}

pub fn main() !void  {
    rl.setTraceLogLevel(.warning);
    rl.initWindow(1920, 1080, "mesh rendering");
    defer rl.closeWindow();

    var mesh: rl.Mesh =
        initMesh(&.{
            30,-30,0,
            30,30,0,
            -30,30,0,
            -30,-30,0,
        }, &.{
            0,1,2,
            0,2,3,
        });
        //rl.genMeshPoly(4, 40);
        //rl.genMeshCube(30,30,30);

    defer mesh.unload();
    const material: rl.Material = try rl.loadMaterialDefault();

    const camera: rl.Camera = .{
        .position = .{.x=0, .y=0, .z=90},
        .target = .{.x=0, .y=0, .z=0},
        .fovy = 45,
        .up = .{.x=0, .y=1, .z=0},
        .projection = .perspective,
    };
    
    const colors =  [_]u8{
        0xff, 0x00, 0x00, 0xff,
        0x00, 0xff, 0x00, 0xff,
    };

    rl.updateMeshBuffer(mesh,
        rl.gl.rl_default_shader_attrib_location_color, &colors, 6, 0);

    while (!rl.windowShouldClose()) {
        //rl.updateCamera(&camera, .orbital);

        rl.beginDrawing();
        rl.drawFPS(10,10);
        rl.clearBackground(.black);

        rl.beginMode3D(camera);
        mesh.draw(material, .identity());
        rl.endMode3D();

        rl.endDrawing();
    }
}

pub fn _main(init: std.process.Init) !void {
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
        defer rl.endDrawing();
        rl.clearBackground(.black);
        const simcopy = sim;
        var draw = init.io.async(Sim.draw, .{simcopy});
        defer draw.await(init.io);
        // sim.draw();

        try sim.update(rl.getFrameTime());
    }
}
