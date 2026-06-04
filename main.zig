const root = @import("polysim");
const Polygon2D = @import("Polygon2D");
const Sim = @import("Sim");
const std = root.std;
const rl = root.rl;
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
    try sim.init(random, init.gpa);

    while (!rl.windowShouldClose()) {
        const delta = rl.getFrameTime();
        try sim.update(delta);

        rl.beginDrawing();
        rl.clearBackground(.black);
        sim.draw();
        rl.endDrawing();
    }
}
