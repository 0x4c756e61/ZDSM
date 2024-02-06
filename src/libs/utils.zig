const std = @import("std");

const RED = "\x1b[38;2;246;96;96m";
const YELLOW = "\x1b[38;2;255;237;129m";
const GREEN = "\x1b[38;2;179;255;114m";
const BLUE = "\x1b[38;2;86;164;255m";
const GRAY = "\x1b[38;2;57;62;65m";
const DEFAULT = "\x1b[0m";

fn baseLogger(comptime color: []const u8, comptime label: []const u8, comptime fmt: []const u8, args: anytype) !void {
    const timestamp: u64 = @truncate(@abs(std.time.timestamp()));
    var stdout = std.io.getStdOut();

    try std.fmt.format(stdout.writer(), "{s}[{any}:{any}:{any}]{s} {s}{s}{s}\t-- " ++ fmt ++ "\n", .{
        GRAY,
        @as(u5, @truncate((timestamp / 3600) % 24)),
        @as(u6, @truncate((timestamp / 60) % 60)),
        @as(u6, @truncate(timestamp % 60)),
        DEFAULT,
        color,
        label,
        DEFAULT,
    } ++ args);
}

pub fn info(comptime fmt: []const u8, args: anytype) !void {
    try baseLogger(BLUE, "INFO", fmt, args);
}

pub fn warn(comptime fmt: []const u8, args: anytype) !void {
    try baseLogger(YELLOW, "WARN", fmt, args);
}

pub fn err(comptime fmt: []const u8, args: anytype) !void {
    try baseLogger(RED, "ERROR", fmt, args);
}

pub fn success(comptime fmt: []const u8, args: anytype) !void {
    try baseLogger(GREEN, "SUCESS", fmt, args);
}
