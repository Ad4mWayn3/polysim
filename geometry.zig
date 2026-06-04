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

/// Iterates once over every pair, quickly discards possible collisions with
/// Shape2D.aABB(), if in narrow-phase, `checkCollisionPrecise` returns true,
/// calls `handleIdPair` with the ids of the colliding objects.
pub fn broadPhaseBruteForce(Shape2D: type, shapes: []Shape2D,
    context: anytype, checkCollisionPrecise: fn(@TypeOf(context),Shape2D,Shape2D) bool,
    handleIdPairCtx: anytype, handleIdPair: fn (@TypeOf(handleIdPairCtx),usize,usize) void
) void {
    //comptime root.Shape2D.validation.satisfiedBy(Shape2D);

    for (shapes[0..shapes.len-1], 0..) |shape, i| {
        for (shapes[i+1..], i+1..) |shape2, j| {
            // discard impossible collisions with axis-aligned bounding boxes
            // before doing precise checks. Decently faster if the bounding box
            // is cached, and recomputed only on transforms.
            if (!rl.checkCollisionRecs(shape.aABB(), shape2.aABB())) continue;

            if (checkCollisionPrecise(context, shape, shape2))
                handleIdPair(handleIdPairCtx, i,j);
        }
    }
}

/// Sorts `shapes` along the x axis and traverses the list, makes an index
/// interval of possible collisions and does broad phase collision checking in
/// bruteforce.
/// 
/// PERSONAL NOTE: instead of manually handling the interval collision inline,
/// parameterize a callback that deals with the interval, letting caller decide
/// whether to evaluate the interval immediately or store it and handle it later.
pub fn broadPhaseSweepAndPrune(Shape2D: type, shapes: []Shape2D,
    context: anytype, checkCollisionPrecise: fn(@TypeOf(context),Shape2D,Shape2D) bool,
    handleIdPairCtx: anytype, handleIdPair: fn (@TypeOf(handleIdPairCtx),usize,usize) void
) void {
    //comptime root.Shape2D.validation.satisfiedBy(Shape2D);

    // sort shapes by axis
    const lessThan = comptime struct { fn inner(_: void, x: Shape2D, y: Shape2D
    ) bool {
        return x.aABB().x < y.aABB().y;
    } }.inner;
    std.mem.sortUnstable(Shape2D, shapes, {}, lessThan); // assuming the sorting
        // implementation is pattern-defeating quicksort, future calls of this
        // function should take roughly O(n) time since the geometry isn't expected
        // to change drastically from one iteration to the next, otherwise, this
        // approach would be barely better than brute force, and differences
        // wouldn't be noticeable until reasonably large data sets

    // build active intervals and bruteforce check for each.
    var interval: struct{usize,usize} = undefined;
    var i: usize = 0;
    for (shapes[0..shapes.len-1]) |shape|  {
        if (i == shapes.len-1) break;
        interval = .{i,i};

        for (shapes[i..], i..) |shape2, j| {
            const r1, const r2 = struct{rl.Rectangle,rl.Rectangle}
                {shape.aABB(), shape2.aABB()};
            
            // check if the shadows of the rectangles intersect in the `x` axis
            if (root.intersection(f32, .{r1.x, r1.x+r1.width},
                .{r2.x, r2.x+r2.width}) > 0.0
            ) {
                // increment the current interval
                interval[1] = j;
            } else if (interval[1] > interval[0]) {
                broadPhaseBruteForce(Shape2D, shapes[interval[0]..interval[1]],
                    context, checkCollisionPrecise, handleIdPairCtx, handleIdPair);

                // VERY IMPORTANT STATEMENT. The fact that i jumps to j after the
                // inner for loop is done is the whole reason this should run in 
                // O(n) time
                i = j;
                break;
            } else break;

        }
        i += 1;
    }
}
