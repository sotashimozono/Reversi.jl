ENV["GKSwstype"] = "100"   # headless GLMakie

using Test
using TestShards

# Every `test_*.jl` under `test/`, in a deterministic order, each one its own shardable unit.
#
# This replaces `discover_tests`, which walked one and two levels deep by hand. The walk here is
# unbounded, so a third level would be picked up too — and picked up BY BEING ON DISK, which is
# the point: `@shard` shadows `include` inside the block, so a unit is whatever this loop
# includes. There is no list of directories to keep in step with the tree.
#
# Two rules when adding to this, and they are the only two:
#
#   1. SHARED FIXTURES GO ABOVE THIS BLOCK. A helper included inside becomes a unit of its own,
#      lands on ONE shard, and every test file on the other shards that needed it fails.
#   2. ANYTHING THAT IS NOT A `test_*.jl` FILE MUST BE NAMED. The glob does not error on what it
#      does not match; it silently stops running it.
#
# A bare `Pkg.test()` with nothing set in the environment runs all of it, in this order. Run one
# shard locally with `TESTSHARDS_ID=s2 TESTSHARDS_N=4 julia --project -e 'using Pkg; Pkg.test()'`.
TestShards.@shard begin
    for (dir, _, files) in sort!(collect(walkdir(@__DIR__)))
        for f in sort(files)
            startswith(f, "test_") && endswith(f, ".jl") || continue
            include(joinpath(dir, f))
        end
    end
end
