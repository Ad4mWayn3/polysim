const root = @import("polysim");
const Polygon2D = @import("Polygon2D");
const Sim = @import("Sim");
const std = root.std;
const rl = root.rl;
const rgui = root.rgui;

const tau = std.math.tau;

const State = struct {
    vertices: [200]rl.Vector2,
    polygons: [20]Polygon2D,
    dragging: std.StaticBitSet(5),
    rand: std.Random,
    
    fn init(self: *@This(), io: std.Io) void {
        var buf: [8]u8 = undefined;
        io.random(&buf);
        self.rand = @constCast(&std.Random.DefaultPrng.init(@as(u64,@bitCast(buf)))).random();
        self.vertices = [_]rl.Vector2{
            .{ .x = 90, .y = 40 },
            .{ .x = 47, .y = 203 },
            .{ .x = 155, .y = 293 },
            .{ .x = 368, .y = 140 },
            .{ .x = 302, .y = 55 },
            .{ .x = 547, .y = 266 },
            .{ .x = 553, .y = 526 },
            .{ .x = 772, .y = 575 },
            .{ .x = 875, .y = 397 },
            .{ .x = 832, .y = 208 }
        } ++ [_]rl.Vector2{undefined}**190;
        self.polygons = [_]Polygon2D {
            .init(self.vertices[0..5]) }
        ++ .{undefined}**19;
        _ = self.polygons[0].transformCentered(.scale(0.5,0.5,0.5));
        for (self.polygons[1..], 0..) |*p, i| {
            p.* = .initRegular(self.vertices[6*i+9..6*i+9+6], 6,
                self.rand.float(f32)*60.0, root.randomVec2(self.rand).multiply(root.screenV()));
        }
        self.dragging = .initEmpty();
    }
};

var mem: [30]rl.Vector2 = undefined;

pub fn _main(init: std.process.Init) !void {
    rl.setTraceLogLevel(.warning);
    rl.initWindow(1200, 600, "polysim");
    defer rl.closeWindow();

    var self: State = undefined;
    self.init(init.io);

    while (!rl.windowShouldClose()) {
        const mouse = rl.getMousePosition();

        // drag vertices individually
        for (self.polygons[0].cast(), 0..) |*v, i| {
            if (rl.isMouseButtonPressed(.left)
                and rl.checkCollisionPointCircle(mouse, v.*, 3.4)
            ) self.dragging.set(i)
            else if (rl.isMouseButtonReleased(.left)) self.dragging.unset(i) ;
            if (self.dragging.isSet(i))
                v.* = v.add(rl.getMouseDelta());
            // if (rl.isMouseButtonDown(.middle))
            //     v.* = v.add(rl.getMouseDelta());
        }

        // drag first polygon
        if (rl.isMouseButtonDown(.right)) {
            const v = rl.getMouseDelta();
            const translate = rl.Matrix.translate(v.x,v.y,0);
            _ = self.polygons[0].transform(translate);
        }

        // rotate first polygon
        const poly = &self.polygons[0];
        _ = poly.transform(poly.rotateMatrix(tau * 1.0/32.0 * rl.getMouseWheelMove()));
        //_ = self.polygons[1].rotate(tau * 0.6 * rl.getFrameTime());

        //var axis: rl.Vector2 = undefined;
        var polycolor: rl.Color = .blue;
        //if (minCollisionDepthAxes(self.polygons[0].cast(),
          //  self.polygons[1].cast(), axes, &axis) > 0.0) .init(0xff,0,0,0x80) else .blue;
        for (self.polygons[1..]) |p| {
            if (self.polygons[0].collisionDepth(p, &mem) > 0.0)
                polycolor = .init(0xff,0,0,0x80);
        }

        rl.beginDrawing();

        rl.clearBackground(.black);
        //self.polygons[1].draw(.beige);
        self.polygons[0].draw(polycolor);
        self.polygons[2].draw(.beige);
        rl.drawRectangleLinesEx(self.polygons[0].aABB(), 2.5, .white);

        // draw each vertex + label
        var buf: [16]u8 = undefined;
        for (self.polygons[0].cast(), 0..) |v, i| {
            rl.drawLineV(v, v.add(self.polygons[0].axis(i).scale(40)), .white);
            rl.drawCircleV(v, 3.4, .red);
            const len = std.fmt.printInt(&buf, i, 10, .lower, .{});
            buf[len] = 0;
            rl.drawText(buf[0..len :0], @intFromFloat(v.x), @intFromFloat(v.y), 16, .white);
        }

        // draw and transform each polygon
        for (self.polygons[1..]) |*p| {
            p.draw(.gold);
            _ = p.transformCentered(.rotateZ(tau/3.0 * rl.getFrameTime()));
        }

        rl.drawCircleV(self.polygons[0].center(), 3.4, .white);

        rl.endDrawing();

        if (rgui.button(.{.x = 900, .y = 20, .width = 100, .height = 40}, "print vertices")
        ) {
            std.debug.print("{any}\n", .{self.polygons[2].vertices});
        }
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
