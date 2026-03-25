const std=@import("std");pub fn build(b:*std.Build) void{_ = std;_ = b.dependency("zstd", .{});}
