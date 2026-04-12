const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");

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

fn polyAxis(polygon: []rl.Vector2, i: usize) rl.Vector2 {
    const len = polygon.len;
    const u, const v = .{polygon[i], polygon[(i+1)%len]};
    const w = v.subtract(u);
    return rl.Vector2.init(-w.y, w.x).normalize();
}

fn polyAxes(polygon: []rl.Vector2, buf: []rl.Vector2) []rl.Vector2 {
    const len = polygon.len;
    std.debug.assert(buf.len >= len);
    for (0..len) |i| {
        buf[i] = polyAxis(polygon, i);
    }
    return buf[0..len];
}

fn polyCenter(polygon: []rl.Vector2) rl.Vector2 {
    var res = rl.Vector2.zero();
    for (polygon) |vertex|
        res = res.add(vertex);
    return res.scale(1.0/@as(f32,@floatFromInt(polygon.len)));
}

fn drawPoly(polygon: []rl.Vector2, color: rl.Color) void { 
    const c = polyCenter(polygon);
    const l = polygon.len;
    for (0..l) |i| {
        const j = (i+1)%l;
        rl.drawTriangle(c, polygon[i], polygon[j], color);
    }
}

const State = struct {
    vertices: [5]rl.Vector2,
    shape2: [5]rl.Vector2,
    dragging: std.StaticBitSet(5),
    fn init(self: *@This()) void {
        comptime {
            if (@TypeOf(self.dragging).bit_length != self.vertices.len)
                @compileError("bit set doesnt match array lenght");
        }
        self.vertices = .{
            .{ .x = 90, .y = 40 },
            .{ .x = 47, .y = 203 },
            .{ .x = 155, .y = 293 },
            .{ .x = 368, .y = 140 },
            .{ .x = 302, .y = 55 },
        };
        self.shape2 = .{.{ .x = 547, .y = 266 }, .{ .x = 553, .y = 526 }, .{ .x = 772, .y = 575 }, .{ .x = 875, .y = 397 }, .{ .x = 832, .y = 208 }};
        self.dragging = .initEmpty();
    }
};



pub fn main() !void {
    rl.initWindow(1200, 800, "polysim");
    defer rl.closeWindow();

    var self: State = undefined;
    self.init();

    while (!rl.windowShouldClose()) {
        const mouse = rl.getMousePosition();
        for (&self.vertices, 0..) |*v, i| {
            if (rl.isMouseButtonPressed(.left)
                and rl.checkCollisionPointCircle(mouse, v.*, 3.4)
            ) self.dragging.set(i)
            else if (rl.isMouseButtonReleased(.left)) self.dragging.unset(i) ;
            if (self.dragging.isSet(i))
                v.* = v.add(rl.getMouseDelta());
            if (rl.isMouseButtonDown(.middle))
                v.* = v.add(rl.getMouseDelta());
        }

        var axesMem: [0x10]rl.Vector2 = undefined;
        _ = polyAxes(&self.vertices, &axesMem);
        _ = polyAxes(&self.shape2, axesMem[5..]);
        const axes = axesMem[0..10];

        var axis: rl.Vector2 = undefined;
        const polycolor: rl.Color = if (minCollisionDepthAxes(&self.vertices, &self.shape2,
            axes, &axis) > 0.0) .init(0xff,0,0,0x80) else .blue;

        rl.beginDrawing();

        rl.clearBackground(.black);
        drawPoly(self.shape2[0..], .beige);
        drawPoly(self.vertices[0..], polycolor);

        for (self.vertices, 0..) |v, i| {
            rl.drawLineV(v, v.add(polyAxis(self.vertices[0..], i).scale(40)), .white);
            rl.drawCircleV(v, 3.4, .red);
            var buf: [16]u8 = undefined;
            const len = std.fmt.printInt(&buf, i, 10, .lower, .{});
            buf[len] = 0;
            rl.drawText(buf[0..len :0], @intFromFloat(v.x), @intFromFloat(v.y), 16, .white);
        }

        rl.drawCircleV(polyCenter(&self.vertices), 3.4, .white);

        rl.endDrawing();

        if (rgui.button(.{.x = 900, .y = 20, .width = 100, .height = 40}, "print vertices")
        ) {
            std.debug.print("{any}\n", .{self.vertices[0..]});
        }
    }
}
