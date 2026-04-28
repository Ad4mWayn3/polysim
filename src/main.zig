const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");

const tau = std.math.tau;

pub fn intersection(Num: type,
    x: struct{Num,Num}, y: struct{Num,Num},
) Num {
    std.debug.assert(x[0] < x[1] and y[0] < y[1]);
    return @min(x[1],y[1]) - @max(x[0],y[0]);
}

pub fn collisionDepthAxis(xs: []rl.Vector2, ys: []rl.Vector2,
    axis: rl.Vector2
) f32 {
    var dot = .{xs[0].dotProduct(axis), ys[0].dotProduct(axis)};
    var x = .{.min = dot[0], .max = dot[0]};
    var y = .{.min = dot[1], .max = dot[1]};
    for (0..@max(xs.len,ys.len)) |i| {
        dot = .{xs[i].dotProduct(axis), ys[i].dotProduct(axis)};
        if (i<xs.len) {
            if (dot[0] < x.min) x.min = dot[0]
            else if (dot[0] > x.max) x.max = dot[0];
        }
        if (i<ys.len) {
            if (dot[1] < y.min) y.min = dot[1]
            else if (dot[1] > y.max) y.max = dot[1];
        }
    }
    return intersection(f32,.{x.min,x.max},.{y.min,y.max});
}

/// Finds the axis with least collision depth in `axes`, stores it to `minAxis`
/// and returns the depth. Negative depth means the stored `minAxis` is a
/// separating axis, and the polygons aren't colliding. May not be sufficient
/// for accurate collision checking if not enough `axes` are provided or either
/// `xs` or `ys` are non-convex.
pub fn minCollisionDepthAxes(xs: []rl.Vector2, ys: []rl.Vector2,
    axes: []rl.Vector2, minAxis: *rl.Vector2
) f32 {
    std.debug.assert(xs.len*ys.len*axes.len != 0); // no empty arrays
    var minDepth = std.math.floatMax(f32);
    for (axes) |axis| {
        //std.debug.assert(@abs(axis.length()-1.0) < 0.1);
        const depth = collisionDepthAxis(xs, ys, axis);
        if (depth < minDepth) {
            minDepth = depth;
            minAxis.* = axis;
        }
        if (depth < 0.0)
            return depth;
    }
    return minDepth;
}

fn randomVec2(r: std.Random) rl.Vector2 {
    return .init(r.float(f32),r.float(f32));
}

fn screenV() rl.Vector2 {
    return .init(@floatFromInt(rl.getScreenWidth()),
        @floatFromInt(rl.getScreenHeight()));
}

const Polygon2D = struct {
    vertices: []rl.Vector2,

    /// lightweight iterator that transforms vertices only when needed
    const TransformIterator = struct {
        vertices: [*]rl.Vector2,
        len: usize,
        transform: rl.Matrix,
        index: usize = 0,

        fn init(vertices: []rl.Vector2, m: rl.Matrix) @This() {
            return .{ 
                .vertices = vertices,
                .len = vertices.len,
                .transform = m
            };
        }

        fn next(self: *@This()) ?rl.Vector2 {
            if (self.index == self.len) return null;
            const e = self.vertices[self.index].transform(self.transform);
            self.index += 1;
            return e;
        }
    };

    fn cast(self: @This()) []rl.Vector2 { return self.vertices; }

    fn initRegular(mem: []rl.Vector2, sides: u8, size: f32, offset: rl.Vector2) @This() {
        std.debug.assert(mem.len >= sides);
        const fract = 1.0 / @as(f32,@floatFromInt(sides));
        for (0..sides) |i| {
            const theta = -@as(f32,@floatFromInt(i)) * tau * fract;
            const sin, const cos = .{@sin(theta), @cos(theta)};
            mem[i] = rl.Vector2.init(cos,sin).scale(size).add(offset);
        }
        return .init(mem[0..sides]);
    }

    fn init(vertices: []rl.Vector2) @This() { return .{ .vertices = vertices }; }

    fn transform(self: *@This(), f: rl.Matrix) *@This() {
        for (self.vertices) |*v|
            v.* = v.transform(f);
        return self;
    }

    const Radians = f32;
    fn rotate(self: *@This(), theta: Radians) *@This() {
        return self.transform(self.rotateMatrix(theta));
    }

    /// Returns `m` but using the polygon's geometric center as origin. Useful
    /// for non-translating transformations
    fn centeredMatrix(self: @This(), m: rl.Matrix) rl.Matrix {
        const c = self.center();
        const t = rl.Matrix.translate(c.x,c.y,0);
        const tInv = rl.Matrix.translate(-c.x,-c.y,0);
        return tInv.multiply(m).multiply(t);
    }

    fn rotateMatrix(self: @This(), theta: Radians) rl.Matrix {
        return self.centeredMatrix(.rotateZ(theta));
    }

    fn axis(self: @This(), i: usize) rl.Vector2 {
        const len = self.vertices.len;
        const u, const v = .{self.vertices[i], self.vertices[(i+1)%len]};
        const w = v.subtract(u);
        return rl.Vector2.init(-w.y, w.x).normalize();
    }

    fn aABB(self: @This()) rl.Rectangle {
        var xmin = self.vertices[0].x;
        var xmax = xmin;
        var ymin = self.vertices[0].y;
        var ymax = ymin;
        for (self.vertices[1..]) |v| {
            if (v.x < xmin) xmin = v.x;
            if (v.x > xmax) xmax = v.x;
            if (v.y < ymin) ymin = v.y;
            if (v.y > ymax) ymax = v.y;
        }
        return .{.x=xmin, .y=ymin, .width=@abs(xmax-xmin), .height=ymax-ymin};
    }

    fn axes(self: @This(), buf: []rl.Vector2) []rl.Vector2 {
        const len = self.vertices.len;
        std.debug.assert(buf.len >= len);
        for (0..len) |i| {
            buf[i] = self.axis(i);
        }
        return buf[0..len];
    }

    fn center(self: @This()) rl.Vector2 {
        var res = rl.Vector2.zero();
        for (self.vertices) |vertex|
            res = res.add(vertex);
        return res.scale(1.0/@as(f32,@floatFromInt(self.vertices.len)));
    }

    fn draw(self: @This(), color: rl.Color) void { 
        const c = self.center();
        const l = self.vertices.len;
        for (0..l) |i| {
            const j = (i+1)%l;
            rl.drawTriangle(c, self.vertices[i], self.vertices[j], color);
        }
    }
};

const State = struct {
    vertices: [20]rl.Vector2,
    polygons: [3]Polygon2D,
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
        } ++ [_]rl.Vector2{undefined}**10;
        self.polygons = .{
            .init(self.vertices[0..5]),
            .init(self.vertices[5..10]),
            .initRegular(self.vertices[10..18], 8, 90, randomVec2(self.rand).multiply(screenV())) };
        self.dragging = .initEmpty();
    }
};

pub fn main(init: std.process.Init) !void {
    rl.initWindow(1200, 800, "polysim");
    defer rl.closeWindow();

    var self: State = undefined;
    self.init(init.io);

    while (!rl.windowShouldClose()) {
        const mouse = rl.getMousePosition();
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

        if (rl.isMouseButtonDown(.middle)) {
            const v = rl.getMouseDelta();
            const translate = rl.Matrix.translate(v.x,v.y,0);
            _ = self.polygons[0].transform(translate);
        }

        const poly = &self.polygons[0];
        _ = poly.transform(poly.rotateMatrix(tau * 1.0/32.0 * rl.getMouseWheelMove()));
        _ = self.polygons[1].rotate(tau * 0.6 * rl.getFrameTime());

        var axesMem: [0x10]rl.Vector2 = undefined;
        _ = self.polygons[0].axes(&axesMem);
        _ = self.polygons[1].axes(axesMem[5..]);
        const axes = axesMem[0..10];

        var axis: rl.Vector2 = undefined;
        const polycolor: rl.Color = if (minCollisionDepthAxes(self.polygons[0].cast(),
            self.polygons[1].cast(), axes, &axis) > 0.0) .init(0xff,0,0,0x80) else .blue;

        rl.beginDrawing();

        rl.clearBackground(.black);
        //self.polygons[1].draw(.beige);
        self.polygons[0].draw(polycolor);
        self.polygons[2].draw(.beige);
        rl.drawRectangleLinesEx(self.polygons[0].aABB(), 2.5, .white);

        for (self.polygons[0].cast(), 0..) |v, i| {
            rl.drawLineV(v, v.add(self.polygons[0].axis(i).scale(40)), .white);
            rl.drawCircleV(v, 3.4, .red);
            var buf: [16]u8 = undefined;
            const len = std.fmt.printInt(&buf, i, 10, .lower, .{});
            buf[len] = 0;
            rl.drawText(buf[0..len :0], @intFromFloat(v.x), @intFromFloat(v.y), 16, .white);
        }

        rl.drawCircleV(self.polygons[0].center(), 3.4, .white);

        rl.endDrawing();

        if (rgui.button(.{.x = 900, .y = 20, .width = 100, .height = 40}, "print vertices")
        ) {
            std.debug.print("{any}\n", .{self.polygons[2].vertices});
        }
    }
}
