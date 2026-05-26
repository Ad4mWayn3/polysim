const Polygon2D = @import("Polygon2D");
const root = @import("polysim");
const rl = root.rl;
const std = root.std;

pub const NarrowPhaseResult = struct {
    collides: bool,

    depth: f32 = 0,
    normal: rl.Vector2 = .{},

    // metrics
    iterations: u32 = 0,
    axes_tested: u32 = 0,
    support_calls: u32 = 0,

    ns: u64 = 0,
};

pub const BroadPhaseResult = struct {
    pair_count: usize,

    tests: usize = 0,
    ns: u64 = 0,
};

pub const Pair = struct {
    a: u32,
    b: u32,
};

pub const Simplex = struct {
    points: [3]rl.Vector2,
    len: u8,
};

pub fn sat(a: Polygon2D, b: Polygon2D, axes_buf: []rl.Vector2) NarrowPhaseResult {
    _ = .{ a, b, axes_buf };
}

pub fn gjk(a: Polygon2D, b: Polygon2D, simplex: *Simplex) NarrowPhaseResult {
    _ = .{ a, b, &simplex };
}

pub fn support(vertices: []const rl.Vector2, dir: rl.Vector2) rl.Vector2 {
    _ = .{ vertices, dir };
}

pub fn sweepAndPrune(aabbs: []const rl.Rectangle, pairs_out: []Pair) []Pair {
    _ = .{ aabbs, pairs_out };
}

/// TODO: change placeholder
const GridScratch = void;

pub fn uniformGrid(aabbs: []const rl.Rectangle, cell_size: f32,
	scratch: *GridScratch, pairs_out: []Pair,
) []Pair {
    _ = .{ aabbs, cell_size, &scratch, pairs_out };
}

// pub const Body = struct {
//     poly: Polygon2D,
//     aabb: rl.Rectangle,
// };
