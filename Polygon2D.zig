pub const root = @import("polysim");
pub const Scene = root.SceneT(@This());
const rl = root.rl;
const std = root.std;
const tau = std.math.tau;

vertices: []rl.Vector2,
comptime gpa: std.mem.Allocator = std.heap.page_allocator,

pub fn cast(self: @This()) []rl.Vector2 { return self.vertices; }

pub fn collisionDepth(self: @This(), other: @This(), mem: []rl.Vector2) f32 {
	const a1 = self.axes(mem);
	const a2 = other.axes(mem[self.vertices.len..]);
	var axs: rl.Vector2 = undefined;
	return root.minCollisionDepthAxes(self.cast(), other.cast(), mem[0..a1.len+a2.len], &axs);
}

pub fn minMaxAxis(self: @This(), axs: rl.Vector2) struct{rl.Vector2,rl.Vector2} {
	var min, var max = .{self.vertices[0], self.vertices[0]};
	for (self.vertices[1..]) |v| {
		const dot = v.dotProduct(axs);
		if (dot < min.dotProduct(axs)) min = v;
		if (dot > max.dotProduct(axs)) max = v;
	}
	return .{min,max};
}

pub fn minkowskiDiff(self: @This(), other: @This(), mem: []rl.Vector2) @This() {
	_ = .{self,other,mem};
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
	return .{ .vertices = vertices };
}

pub fn transform(self: *@This(), f: rl.Matrix) *@This() {
	for (self.vertices) |*v|
		v.* = v.transform(f);
	return self;
}

pub fn transformCentered(self: *@This(), m: rl.Matrix) *@This() {
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