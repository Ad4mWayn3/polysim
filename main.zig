const root = @import("polysim");
const Polygon2D = @import("Polygon2D");
const Sim = @import("Sim");
const std = root.std;
const rl = root.rl;
const rgui = root.rgui;

const tau = std.math.tau;

fn uSub(a: anytype, b: anytype) ?@TypeOf(a) {
    return if (a >= b) a - b else null;
}

fn vecLowerThan(_: void, v: rl.Vector2, u: rl.Vector2) bool {
    return v.y > u.y; // v will appear physically lower in screen coordinates
        // if the `y` coordinate is greater.
}

fn vecAngleLessThan(origin: rl.Vector2, x: rl.Vector2, y: rl.Vector2) bool {
    return root.wedge(x.subtract(origin),y.subtract(origin)) < 0.0;
}

const State = struct {
    vertices: [200]rl.Vector2,
    random: std.Random.DefaultPrng,
    loopState: struct {
        i: usize = 0,
        sorted: bool = false,
    },
    
    fn init(self: *@This(), io: std.Io) void {
        self.loopState = .{};

        var seed: u64 = undefined;
        io.random(@as(*[8]u8,@ptrCast(&seed)));
        self.random.seed(seed);

        for (&self.vertices) |*v| {
            v.* = root.randomVec2(self.random.random())
                .multiply(root.screenV());
        }
    }

    fn update(self: *@This(), delta: f32) void {
        _ = delta;

        {
        const i = &self.loopState.i;
        if (rl.isMouseButtonPressed(.left))
            i.* = (i.* + 1) % self.vertices.len;
        if (rl.isMouseButtonPressed(.right))
            i.* = uSub(i.*,1) orelse self.vertices.len-1;
        }

        if (rl.isKeyPressed(.enter) and !self.loopState.sorted) {
            self.loopState.sorted = true;
            const i = std.sort.argMin(rl.Vector2, &self.vertices, {},
                vecLowerThan).?;
            if (i != 0) std.mem.swap(rl.Vector2, &self.vertices[i],
                &self.vertices[0]);
            std.mem.sortUnstable(rl.Vector2, self.vertices[1..],
                self.vertices[0], root.isCounterClockwise);
        }
    }

    fn draw(self: @This()) void {
        for (self.vertices, 0..) |v, i| {
            if (i == self.loopState.i) rl.drawCircleV(v, 5.2, .white)
            else rl.drawCircleV(v, 4.1, .red);
        }
    }
};

var state: State = undefined;

pub fn _main(init: std.process.Init) !void {
    rl.setTraceLogLevel(.warning);
    rl.initWindow(1200, 600, "polysim");
    defer rl.closeWindow();

    var self = &state;
    self.init(init.io);

    while (!rl.windowShouldClose()) {
        self.update(rl.getFrameTime());
        rl.beginDrawing();
        rl.clearBackground(.black);
        self.draw();
        rl.endDrawing();
    }
}

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
    try sim.init(random);

    while (!rl.windowShouldClose()) {
        const delta = rl.getFrameTime();
        try sim.update(delta);

        rl.beginDrawing();
        rl.clearBackground(.black);
        sim.draw();
        rl.endDrawing();
    }
}
