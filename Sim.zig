const root = @import("polysim");
const std = root.std;
const rl = root.rl;
const Polygon2D = @import("Polygon2D");
const Scene = Polygon2D.Scene;
const geometry = @import("geometry");

scene: Scene,
hulls: [4]Polygon2D,
selected: std.bit_set.ArrayBitSet(u8, Scene.polyCount),
current: i32 = -1,
pressed: bool = false,
transform: enum { none, slide, rotate, scale },
collisionAxes: [(Scene.vertPerPoly)*2]rl.Vector2,
//aux: [20]rl.Vector2,
drawStack: [90]rl.Vector2, // maybe unused?
//transforms: [90]root.Transform2D,
colliding: std.bit_set.IntegerBitSet(90),
//collisionPairs: []struct{usize,usize},

pub fn init(self: *@This(), random: std.Random, gpa: std.mem.Allocator) !void {
    //_ = .{&self,scene};
    self.selected = .empty;
    self.current = -1;
    self.colliding = .initEmpty();
    _ = gpa;
    //self.collisionPairs = try gpa.alloc(struct{usize,usize},1);

    // initialize scene data
    const count = Scene.vertPerPoly;
    self.scene.vertices = undefined;
    for (&self.scene.objects, 0..) |*obj, i| {
        const mem = self.scene.vertices[i * count .. i * count + count];
        obj.* = .initRegular(mem, count, random.float(f32) * 30 + 20,
        	root.randomVec2(random).multiply(root.screenV().scale(0.7)).add(.init(60,60)));
        obj.aABBcache = obj.aABB();
        if (i < 90) self.drawStack[i] = root.randomVec2(random)
            .scale(500);
            // .multiply(root.screenV());
    }

    // sort scene objects by their x axis
    std.mem.sortUnstable(Polygon2D, &self.scene.objects, {}, struct {
        fn lessThan(_: void, x: Polygon2D, y: Polygon2D) bool {
            return x.aABBcache.x < y.aABBcache.x;
        }
    }.lessThan);

    var inner: []rl.Vector2 = self.drawStack[0..];
    for (&self.hulls) |*hull| {
        if (inner.len <= 2) break;
        hull.*, inner = Polygon2D.initHull(inner, std.heap.page_allocator);
    }
}

pub fn update(self: *@This(), delta: f32) !void {
    const mouse, const mouseDelta = .{ rl.getMousePosition(), rl.getMouseDelta() };
    _ = .{ mouseDelta, delta };

    self.colliding = .initEmpty();

    // var transform: enum {none,slide,rotate,scale} = .none;
    self.pressed = false;
    if (rl.isMouseButtonPressed(.left))
        self.transform, self.pressed = .{ .slide, true };
    if (rl.isMouseButtonPressed(.right))
        self.transform, self.pressed = .{ .rotate, true };
    if (rl.isMouseButtonPressed(.middle))
        self.transform, self.pressed = .{ .scale, true };
    if (rl.isMouseButtonReleased(.left) or rl.isMouseButtonReleased(.right) 
        or rl.isMouseButtonReleased(.middle)
    ) {
        self.transform = .none;
    }

    // check whether the mouse touches a polygon's bounding box
    var found = false;
    if (self.transform != .none and self.pressed) for (self.scene.objects, 0..) |poly, i| {
        if (rl.checkCollisionPointRec(mouse, poly.aABBcache)) {
            self.current = @intCast(i);
            found = true;
        }
    };
    self.current = if (found or self.transform != .none) self.current else -1;

    // full collision detection process
    const checkCollisionPoly = comptime struct { 
    fn f(mem: []rl.Vector2, poly1: Polygon2D, poly2: Polygon2D) bool {
        return poly1.collisionDepth(poly2, mem) > 0.0;
    }}.f;
    const handleIdPair = comptime struct {
    fn f(bitset: *@TypeOf(self.colliding), i: usize,
        j: usize
    ) void {
        bitset.set(i);
        bitset.set(j);
    }}.f;
    // collision detection happens here:
    geometry.broadPhaseBruteForce(Polygon2D, &self.scene.objects,
        @as([]rl.Vector2,&self.collisionAxes), checkCollisionPoly,
        &self.colliding, handleIdPair);

    // rotates or translates the currently selected polygon.
    // TODO implement scaling
    if (self.current >= 0 and self.transform != .none) {
        std.debug.assert(self.current < Scene.polyCount);
        var curr = &self.scene.objects[@intCast(self.current)];
        _ = switch (self.transform) {
            .none => null,
            .slide => curr.transform(.translate(mouseDelta.x, mouseDelta.y, 0)),
            .rotate => curr.transformCentered(.rotateZ(mouseDelta.x / 50.0)),
            .scale => null,
            //.scale => curr.transformCentered(.scale
        };
    }
}

pub fn draw(self: *@This()) void {
    defer rl.drawFPS(30, 30);

    //self.colliding = .initEmpty();
    for (self.scene.objects[0 .. self.scene.objects.len - 1], 0..) |poly, i| {
        // for (self.scene.objects[i+1..], i+1..) |poly2,j| {
        //     if (!poly.aABBcache.checkCollision(poly2.aABBcache)) continue;

        //     if (poly.collisionDepth(poly2, &self.aux) > 0.0) {
        //         self.colliding.set(i);
        //         self.colliding.set(j);
        //     }
        // }

        //rl.drawRectangleLinesEx(poly.aABBcache, 2.1, .blue);

        poly.draw(.{
            .fill = .dark_gray,
            .outline = .{
                .color = if (self.colliding.isSet(i)) .red else .white, 
                .thick = 3.2 } });
    }
    self.scene.objects[self.scene.objects.len - 1]
        .draw(.{ .fill = null, .outline = .{ .color = .white, .thick = 3.2 } });

    // const hull: Polygon2D = .initHull(&self.scene.vertices, std.heap.page_allocator);
    // for (self.hulls) |hull|
    //     hull.draw(.{ .fill = null, .outline = .{ .color = .blue, .thick = 3.4 } });
}
