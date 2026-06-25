pub const rl = @import("raylib");
pub const rgui = @import("raygui");
pub const std = @import("std");
pub const Interface = @import("interface").Interface;

const tau = std.math.tau;

/// TODO: replace this type
const Inner = void;

pub const Shape2D = Interface(.{
    .aABB = fn (Inner) rl.Rectangle,
    .position = fn (Inner) rl.Vector2,
}, null);

pub fn SceneT(Polygon2D: type, comptime vCount: usize, pCount: usize
) type { return struct {
    pub const vertCount: usize = pCount*vCount;
    pub const polyCount: usize = pCount;
    pub const vertPerPoly: usize = vCount;

    vertices: [vertCount]rl.Vector2,
    objects: [polyCount]Polygon2D,
}; }

pub fn Child(T: type) type {
    const info = @typeInfo(T);
    return switch (info) {
    .pointer => |p| p.child,
    .array => |a| a.child,
    .optional => |o| o.child,
    else => @compileError("type " ++ @typeName(T) ++ " is not a pointer, array, "
        ++ "optional or slice.\n"),
    };
}

pub fn DoubleStack(T: type) type { return struct {
    buf: [*]T,
    len: usize,
    frontLen: usize = 0,
    backLen: usize = 0,
    const Place = enum { front, back,
        fn opposite(self: Place) Place { return switch(self) {
            .front=>.back,
            .back=>.front,
        };}
    };

    pub fn initEmpty(buf: []T) @This() {
        return @This(){.buf = buf.ptr, .len=buf.len};
    }

    /// Returns the stack at the beginning of the array.
    /// *note*: Element at index 0 is the last one in the stack
    pub fn front(self: @This()) []T { return self.buf[0..self.frontLen]; }

    pub fn back(self: @This()) []T { return self.buf[self.len-self.backLen..self.len]; }

    pub fn head(self: *@This(), at: Place) ?*T {
        return switch (at) {
        .front => if (self.frontLen != 0) &self.buf[self.frontLen-1] else null,
        .back => if (self.backLen != 0) &self.buf[self.len-self.backLen]
            else null,
        };
    }

    pub fn headAssertNotEmpty(self: *@This(), at: Place) *T {
        if (self.isEmpty(at)) unreachable;
        return switch (at) {
        .front => &self.buf[self.frontLen-1],
        .back => &self.buf[self.len-self.backLen],
        };
    }

    pub fn isFull(self: @This()) bool {
        return self.frontLen + self.backLen == self.len;
    }

    pub fn isEmpty(self: @This(), at: Place) bool {
        return switch (at) {
        .front => self.frontLen == 0,
        .back => self.backLen == 0,
        };
    }

    pub fn push(self: *@This(), at: Place, x: T) error{full}!*T {
        if (self.isFull()) return error.full;
        return self.pushAssertNotFull(at, x);
    }

    pub fn pushAssertNotFull(self: *@This(), at: Place, x: T) *T {
        if (self.isFull()) unreachable;
        switch (at) {
        .front => {
            self.frontLen += 1;
            self.buf[self.frontLen-1] = x;
            return &self.buf[self.frontLen-1];
        }, .back => {
            self.backLen += 1;
            self.buf[self.len-self.backLen] = x;
            return &self.buf[self.len-self.backLen];
        },}
    }

    pub fn pop(self: *@This(), at: Place) error{empty}!T {
        if (self.isEmpty(at)) return error.empty;
        return self.popAssertNotEmpty(at);
    }

    pub fn popAssertNotEmpty(self: *@This(), at: Place) T {
        if (self.isEmpty(at)) unreachable;
        const out = self.headAssertNotEmpty(at).*;
        switch (at) {
        .front => self.frontLen -= 1,
        .back => self.backLen -= 1,
        }
        return out;
    }

    /// pops off the stack at `from` and pushes to the opposite. returns
    /// the destination address
    pub fn transfer(self: *@This(), from: Place) error{empty}!*T {
        if (self.isEmpty(from)) return error.empty;
        return self.transferNotEmpty(from);
    }

    pub fn transferNotEmpty(self: *@This(), from: Place) *T {
        if (self.isEmpty(from)) unreachable;
        const x = self.popAssertNotEmpty(from);
        return self.pushAssertNotFull(from.opposite(), x);
    }
};}

pub fn RingBuffer(comptime T: type) type { return struct {
    buf: []T,
    head: usize = 0,

    const Self = @This();

    pub fn init(buf: []T) Self { return .{ .buf = buf }; }

    pub fn len(self: Self) usize { return self.buf.len; }

    pub fn at(self: Self, i: usize) *T {
        return &self.buf[(self.head + i) % self.buf.len];
    }

    pub fn atBackwards(self: Self, i: usize) *T {
        return &self.buf[ (self.head + self.buf.len - (i % self.buf.len))
            % self.buf.len ];
    }

    pub fn iter(self: *Self) ForwardIterator { return .{ .rb = self }; }

    pub fn iterBackwards(self: *Self) BackwardIterator { return .{ .rb = self }; }

    pub const ForwardIterator = struct {
        rb: *Self,
        i: usize = 0,

        pub fn next(self: *@This()) ?*T {
            if (self.i >= self.rb.buf.len)
                return null;
            defer self.i += 1;
            return self.rb.at(self.i);
        }
    };

    pub const BackwardIterator = struct {
        rb: *Self,
        i: usize = 0,

        pub fn next(self: *@This()) ?*T {
            if (self.i >= self.rb.buf.len)
                return null;
            defer self.i += 1;
            return self.rb.atBackwards(self.i);
        }
    };
};}

pub const Transform2D = struct {
    translate: rl.Vector2,
    rotate: f32,
    pub fn rMatrix(self: @This()) rl.Matrix { return .rotateZ(self.rotate); }
    pub fn tMatrix(self: @This()) rl.Matrix {
        return .translate(self.translate.x, self.translate.y, 0);
    }
};

pub const Mesh2D = struct {
    vertices: []f32,
    // uses c_int instead of usize for trivial compatibility with C APIs
    colors: ?[]u8,
    indices: ?[]c_int,
    vaoId: c_int = 0,
    vboId: struct {
        positions: c_int = 0,
        colors: c_int = 0,
        indices: c_int = 0,
    },

    const attribLayout = .{
        .position = 0,
        .color = 1,
    };

    /// uploads the buffers to gpu, generates buffer and array objects
    pub fn upload(mesh: *@This()) void {
        // the buffer objects should all be null at this point
        std.debug.assert(mesh.vaoId + mesh.vboId.positions
            + mesh.vboId.colors + mesh.vboId.indices == 0);

        mesh.vaoId = rl.gl.rlLoadVertexArray();
        _ = rl.gl.rlEnableVertexArray(@intCast(mesh.vaoId));

        // set position attribute and buffer
        mesh.vboId.positions = rl.gl.rlLoadVertexBuffer(mesh.vertices,
            @intCast(mesh.vertices.len * @sizeOf(f32)), true);
        rl.gl.rlSetVertexAttribute(attribLayout.position, 2, rl.gl.rl_float,
            false, @intCast(2*@sizeOf(f32)), 0);
        rl.gl.rlEnableVertexAttribute(attribLayout.position);

        // set color attribute and buffer (if enabled)
        if (mesh.colors) |colors| {
            // 4 bytes are expected per color (r, g, b, a)
            std.debug.assert(colors.len % 4 == 0);
            mesh.vboId.colors = rl.gl.rlLoadVertexBuffer(colors,
                @intCast(colors.len * @sizeOf(u8)), true);
            rl.gl.rlSetVertexAttribute(attribLayout.color, 4,
                rl.gl.rl_unsigned_byte, false, @intCast(4*@sizeOf(u8)), 0);
            rl.gl.rlEnableVertexAttribute(attribLayout.color);
        }

        // set index buffer (if enabled)
        if (mesh.indices) |indices| {
            mesh.vboId.indices = rl.gl.rlLoadVertexBufferElement(indices,
                @intCast(indices.len * @sizeOf(c_int)), true);
        }

        rl.gl.rlDisableVertexArray();
    }

    pub fn draw(mesh: @This()) void {
        _ = mesh;
    }
};

pub const HullSplit = struct {
    hull: []rl.Vector2,
    inner: []rl.Vector2,
};

pub fn ArrayLike(T: type, Context: type) type { return struct {
    atPtr: fn (ctx: Context, xs: anytype, idx: usize) *T,
    at: fn (ctx: Context, xs: anytype, idx: usize) T,
};}

/// Reorders `vertices` to appear conterclockwise. Starts in the direction of
/// `min`.
pub fn sortCounterclockwiseMin(vertices: []rl.Vector2, min: rl.Vector2) void {
    std.mem.sortUnstable(rl.Vector2, vertices, min, 
        struct { fn lessThan(origin: rl.Vector2, x: rl.Vector2, y: rl.Vector2
        ) bool {
            return wedge(x.subtract(origin),y.subtract(origin)) < 0.0;
        }}.lessThan);
}

/// Creates a simple triangulation using the first vertex as a common one.
/// Index must be an integer type. Memory cleanup is the caller's responsibility.
pub fn triangulateSorted(vertices: []const rl.Vector2, gpa: std.mem.Allocator,
    comptime Index: type
) ![]Index {
    // any triangulation will result in n-2 triangles, where n is the number of
    // vertices, assuming the vertex sequence forms a simple polygon.
    var indices = try gpa.alloc(Index, (vertices.len-2) * 3);
    if (vertices.len < 3) return error.TooFewVertices;

    for (0..vertices.len-2) |i| {
        const j = 3*i;
        indices[j] = 0;
        indices[j+1] = @intCast(i+1);
        indices[j+2] = @intCast(i+2);
    }

    return indices;
}

/// Splits the vertices into `hull` and `inner` keeping their clockwise order; `inner`
/// vertices get reordered so that the first element is the bottom-most. Applying
/// recursively to the `inner` split will eventually produce convex layers.
pub fn buildHullAssumeSorted(vertices: []rl.Vector2, mem: []rl.Vector2) HullSplit {
    if (vertices.len <= 3) return .{.hull = vertices, .inner = vertices[0..0]};

    var stack: DoubleStack(rl.Vector2) = .initEmpty(mem[0..vertices.len]);
    inline for (vertices[0..3]) |v| _ = stack.pushAssertNotFull(.front, v);

    // build hull
    var curr, var mid, var prev = [_][*]rl.Vector2{undefined}**3;
    for (vertices[3..], 3..) |*vecPtr, i| {
        _ = i;
        curr = vecPtr[0..1].ptr;
        mid = (stack.head(.front) orelse unreachable)[0..1].ptr;
        prev = peekBack(stack.front(), 1)[0..1].ptr;

        while (!isCounterClockwise(prev[0], mid[0], curr[0]))
        : (_ = stack.transferNotEmpty(.front)) {
            mid -= 1;
            prev -= 1;
        }

        _ = stack.pushAssertNotFull(.front, curr[0]);
    }

    std.mem.copyBackwards(rl.Vector2, vertices, stack.front());

    // find index of bottom-most inner vertex
    var minI: usize = 0;
    const inner = stack.back();
    for (inner[1..], 1..) |v,i| {
        if (v.y > inner[minI].y) minI = i; // lowest point hast greatest y coordinate
            // in screen space
    }

    // write inner vertices from back stack to `vertices` buffer
    var temp = (RingBuffer(rl.Vector2){.buf = inner, .head = minI});
    var innerOrd = temp
        //.iterBackwards();
        .iter();
    _ = copyFromIter(rl.Vector2, vertices[vertices.len-inner.len ..], &innerOrd)
        catch innerOrd;

    return .{.hull = vertices[0..stack.frontLen],
        .inner = vertices[stack.frontLen..]};
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

pub fn wedge(lhs: rl.Vector2, rhs: rl.Vector2) f32 {
    return lhs.x*rhs.y - lhs.y*rhs.x;
}

pub fn isCounterClockwise(offset: rl.Vector2, x: rl.Vector2, y: rl.Vector2) bool {
    return wedge(x.subtract(offset),y.subtract(offset)) < 0;
    // because in most renderers the y axis ascends from top to bottom, we check
    // for a negative wedge product instead of positive
}

pub fn vecLowerThan(_: void, v: rl.Vector2, u: rl.Vector2) bool {
    return v.y > u.y; // v will appear physically lower in screen coordinates
        // if the `y` coordinate is greater.
}

pub fn randomVec2(r: std.Random) rl.Vector2 {
    return .init(r.float(f32),r.float(f32));
}

pub fn randomVec2Radial(r: std.Random) rl.Vector2 {
    const l = r.float(f32);
    const theta = r.float(f32) * tau;
    return (rl.Vector2{.x = @cos(theta), .y = @sin(theta)}).scale(l);
}

pub fn initMesh(vertexBuf: []const f32, indexBuf: []const c_ushort) rl.Mesh {
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

pub fn screenV() rl.Vector2 {
    return .init(@floatFromInt(rl.getScreenWidth()),
        @floatFromInt(rl.getScreenHeight()));
}

pub fn copyFromIter(T: type, dest: []T, iter: anytype) !@TypeOf(iter) {
    for (dest) |*x| {
        if (iter.next()) |y| x.* = y.*
        else return error.smallIterator;
    }
    return iter;
}

pub fn peekBack(slice: anytype, i: usize) *Child(@TypeOf(slice)) {
    const T = Child(@TypeOf(slice));
    const s: []T = slice;
    return &s[s.len-i - 1];
}

/// returns the amount the interval `x` intersects the interval `y`, if they do
/// not intersect, returns the negative distance from each other.
pub fn intersection(Num: type,
    x: struct{Num,Num}, y: struct{Num,Num},
) Num {
    std.debug.assert(x[0] < x[1] and y[0] < y[1]);
    return @min(x[1],y[1]) - @max(x[0],y[0]);
}
