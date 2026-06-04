const NUMERO_LADOS = 9;

pub const root = @import("polysim");
pub const Scene = root.SceneT(@This(), NUMERO_LADOS);
const rl = root.rl;
const std = root.std;
const tau = std.math.tau;

vertices: []rl.Vector2,
aABBcache: rl.Rectangle = undefined,
comptime gpa: std.mem.Allocator = std.heap.page_allocator,

pub fn cast(self: @This()) []rl.Vector2 { return self.vertices; }

/// how much the polygon intersects another in the least intersecting axis.
/// Returns a negative number early if a separating axis is found.
/// 
/// `mem.length` is expected to be at least as big as `self.vertices.len + 
/// other.vertices.len`.
pub fn collisionDepth(self: @This(), other: @This(), mem: []rl.Vector2) f32 {
	const a1 = self.axes(mem);
	const a2 = other.axes(mem[self.vertices.len..]);
	var axs: rl.Vector2 = undefined;
	return root.minCollisionDepthAxes(self.cast(), other.cast(), mem[0..a1.len+a2.len], &axs);
}

pub fn minMaxAxis(self: @This(), axs: rl.Vector2,
	minMaxIds: *struct{usize,usize}
) struct{rl.Vector2,rl.Vector2} {
	var min, var max = .{self.vertices[0], self.vertices[0]};
	const minI, const maxI = .{&minMaxIds[0],&minMaxIds[1]};
	for (self.vertices[1..], 0..) |v, i| {
		const dot = v.dotProduct(axs);
		if (dot < min.dotProduct(axs)) min,minI.* = .{v,i};
		if (dot > max.dotProduct(axs)) max,maxI.* = .{v,i};
	}
	return .{min,max};
}

pub fn minkowskiDiff(self: @This(), other: @This(), mem: []rl.Vector2) @This() {
	_ = .{self,other,mem};
}

/// Creates a hull from a set of points.
pub fn initHull(vertices: []rl.Vector2, gpa: std.mem.Allocator
) struct{@This(),[]rl.Vector2} {
	//const poly: @This() = .init(vertices);

	//self.loopState.sorted = true;
    const i = std.sort.argMin(rl.Vector2, vertices, {},
        root.vecLowerThan).?;
    if (i != 0) std.mem.swap(rl.Vector2, &vertices[i],
        &vertices[0]);
    std.mem.sortUnstable(rl.Vector2, vertices[1..],
        vertices[0], root.isCounterClockwise);
	//std.debug.print("after: {any}\n", .{vertices});

	// build hull
	const mem = gpa.alloc(rl.Vector2, vertices.len) catch unreachable;
	defer gpa.free(mem);
	const partition = root.buildHullAssumeSorted(vertices, mem);
	return .{.init(partition.hull), partition.inner};
}

pub fn initRegular(mem: []rl.Vector2, sides: u8, length: f32, offset: rl.Vector2) @This() {
	std.debug.assert(mem.len >= sides);
	const fract = 1.0 / @as(f32,@floatFromInt(sides));
	for (0..sides) |i| {
		const theta = -@as(f32,@floatFromInt(i)) * tau * fract;
		const sin, const cos = .{@sin(theta), @cos(theta)};
		mem[i] = rl.Vector2.init(cos,sin).scale(length).add(offset);
	}
	return .init(mem[0..sides]);
}

pub fn init(vertices: []rl.Vector2) @This() {
	var out = @This(){.vertices = vertices};
	out.aABBcache = out.aABBCalc();
	return out;
}

pub fn transform(self: *@This(), f: rl.Matrix) *@This() {
	for (self.vertices) |*v|
		v.* = v.transform(f);
	self.aABBcache = self.aABBCalc();
	return self;
}

pub fn transformCentered(self: *@This(), m: rl.Matrix) *@This() {
	//defer self.aABBcache = self.aABB();
	return self.transform(self.centeredMatrix(m));
}

const Radians = f32;
pub fn rotate(self: *@This(), theta: Radians) *@This() {
	return self.transform(self.rotateMatrix(theta));
}

/// Transforms like `m` but the origin is offset to the polygon's geometric center
pub fn centeredMatrix(self: @This(), m: rl.Matrix) rl.Matrix {
	const c = self.center();
	const t = rl.Matrix.translate(c.x,c.y,0);
	const tInv = rl.Matrix.translate(-c.x,-c.y,0);
	return tInv.multiply(m).multiply(t);
}

pub fn rotateMatrix(self: @This(), theta: Radians) rl.Matrix {
	return self.centeredMatrix(.rotateZ(theta));
}

pub fn axis(self: @This(), i: usize) rl.Vector2 {
	const len = self.vertices.len;
	const u, const v = .{self.vertices[i], self.vertices[(i+1)%len]};
	const w = v.subtract(u);
	return rl.Vector2.init(-w.y, w.x).normalize();
}

pub fn aABB(self: @This()) rl.Rectangle {
	return self.aABBcache;
}

fn aABBCalc(self: *@This()) rl.Rectangle {
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
	self.aABBcache = .{.x=xmin, .y=ymin, .width=@abs(xmax-xmin),
		.height=ymax-ymin};
	return self.aABBcache;
}

pub fn axes(self: @This(), buf: []rl.Vector2) []rl.Vector2 {
	const len = self.vertices.len;
	std.debug.assert(buf.len >= len);
	for (0..len) |i| {
		buf[i] = self.axis(i);
	}
	return buf[0..len];
}

pub fn center(self: @This()) rl.Vector2 {
	var res = rl.Vector2.zero();
	for (self.vertices) |vertex|
		res = res.add(vertex);
	return res.scale(1.0/@as(f32,@floatFromInt(self.vertices.len)));
}

const DrawOptions = struct {
	fill: ?rl.Color,
	outline: ?struct{color:rl.Color, thick:f32},
};
pub fn draw(self: @This(), options: DrawOptions) void { 
	const c = self.center();
	const l = self.vertices.len;
	for (0..l) |i| {
		const j = (i+1)%l;
		if (options.fill) |color| rl.drawTriangle(c, self.vertices[i], self.vertices[j], color);
		if (options.outline) |outline|
			rl.drawLineEx(self.vertices[i], self.vertices[j], outline.thick, outline.color);
	}
}