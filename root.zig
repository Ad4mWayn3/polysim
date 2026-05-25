pub const rl = @import("raylib");
pub const rgui = @import("raygui");
pub const std = @import("std");

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
    for (0..@min(xs.len,ys.len)) |i| {
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

pub fn randomVec2(r: std.Random) rl.Vector2 {
    return .init(r.float(f32),r.float(f32));
}

pub fn screenV() rl.Vector2 {
    return .init(@floatFromInt(rl.getScreenWidth()),
        @floatFromInt(rl.getScreenHeight()));
}