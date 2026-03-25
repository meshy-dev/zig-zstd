const std=@import("std");pub fn build(b:*std.Build) void{_ = b.dependency("zstd_repro", .{});_ = b.step("repro","repro");}
