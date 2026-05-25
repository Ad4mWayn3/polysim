const root = @import("polysim");
const std = root.std;
const rl = root.rl;
const Polygon2D = @import("Polygon2D");
const Scene = Polygon2D.Scene;

scene: Scene,
selected: std.bit_set.ArrayBitSet(u8,Scene.polyCount),
current: i32 = -1,
pressed: bool = false,
transform: enum {none,slide,rotate,scale},
aux: [20]rl.Vector2,

pub fn init(self: *@This(), random: std.Random) !void {
	//_ = .{&self,scene};
	self.selected = .empty;
	self.current = -1;

	// initialize scene data
	self.scene.vertices = undefined;
	for (&self.scene.objects,0..) |*obj,i| {
		const mem = self.scene.vertices[i*5..i*5+5];
		obj.* = .initRegular(mem, 5, random.float(f32)*30+20, root.randomVec2(random).multiply(root.screenV()));
	}
}

pub fn update(self: *@This(), delta: f32) !void {
	const mouse, const mouseDelta = .{rl.getMousePosition(), rl.getMouseDelta()};
	_ = .{mouseDelta,delta};

	//var transform: enum {none,slide,rotate,scale} = .none;
	self.pressed = false;
	if (rl.isMouseButtonPressed(.left)) self.transform,self.pressed = .{.slide,true};
	if (rl.isMouseButtonPressed(.right)) self.transform,self.pressed = .{.rotate,true};
	if (rl.isMouseButtonPressed(.middle)) self.transform,self.pressed = .{.scale,true};
	if (rl.isMouseButtonReleased(.left)
		or rl.isMouseButtonReleased(.right)
		or rl.isMouseButtonReleased(.middle)) {
		self.transform = .none;
	}

	// check whether the mouse touches a polygon's bounding box
	var found = false;
	if (self.transform != .none and self.pressed) for (self.scene.objects, 0..) |poly, i| {
		if (rl.checkCollisionPointRec(mouse, poly.aABB())) {
			self.current = @intCast(i);
			found = true;
		}
	};
	self.current = if (found or self.transform != .none) self.current else -1;

	// rotates or translates the currently selected polygon.
	// TODO implement scaling
	if (self.current >= 0 and self.transform != .none) {
		std.debug.assert(self.current < Scene.polyCount);
		var curr = self.scene.objects[@intCast(self.current)];
		_ = switch (self.transform) {
			.none => null,
			.slide => curr.transform(.translate(mouseDelta.x,mouseDelta.y,0)),
			.rotate => curr.transformCentered(.rotateZ(mouseDelta.x/50.0)),
			.scale => null,
			//.scale => curr.transformCentered(.scale
		};
	}
}

pub fn draw(self: *@This()) void {
	rl.drawFPS(30,30);
	for (self.scene.objects[0..self.scene.objects.len-1], 0..) |poly, i| {
		var outline: rl.Color = undefined;
		outline = .white;
		//_ = i;
		for (self.scene.objects[i+1..]) |poly2| {
		 if (poly.collisionDepth(poly2, &self.aux) > 0.0) outline = .red;
		}
		poly.draw(.{.fill=null, .outline=.{.color=outline, .thick=3.2}});
	}
}
