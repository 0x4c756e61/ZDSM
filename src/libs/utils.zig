const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const os = std.os;

const RED = "\x1b[38;2;246;96;96m";
const YELLOW = "\x1b[38;2;255;237;129m";
const GREEN = "\x1b[38;2;179;255;114m";
const BLUE = "\x1b[38;2;86;164;255m";
const GRAY = "\x1b[38;2;57;62;65m";
const DEFAULT = "\x1b[0m";
const MAX_KEY_LEN = 50;
const whitespaces = [_]u8{ ' ', '\t' };

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

pub fn parseKVPair(reader: anytype, key: []const u8, buffer: []u8, delimiter: u8) !?[]const u8 {
    var valuebuffer_stream = std.io.fixedBufferStream(buffer);
    const value_writer = valuebuffer_stream.writer();

    var keybuffer: [MAX_KEY_LEN]u8 = undefined;
    var keybuffer_stream = std.io.fixedBufferStream(&keybuffer);
    var key_writer = keybuffer_stream.writer();

    while (reader.readByte()) |byte| {
        if (byte == delimiter) {
            if (mem.eql(u8, key, keybuffer_stream.getWritten())) {
                // Note : We could write our own implementation of streamUntilDelimiter to account for whitespaces,
                // trimming the spaces in one go
                reader.streamUntilDelimiter(value_writer, '\n', null) catch |e| {
                    err("parseKVPair :  {s}", .{@errorName(e)}) catch {};
                    break;
                };
                return mem.trim(u8, valuebuffer_stream.getWritten(), " ");
            }
            keybuffer_stream.reset();
            try reader.skipUntilDelimiterOrEof('\n');
            continue;
        }

        try key_writer.writeByte(byte);
    } else |_| {
        return null;
    }

    return null;
}

pub fn parseKVPairOpenFile(path: []const u8, key: []const u8, buffer: []u8, delimiter: u8) !?[]const u8 {
    var fileDescriptor = try fs.openFileAbsolute(path, .{ .intended_io_mode = .blocking });
    const file = fileDescriptor.reader();
    defer fileDescriptor.close();

    return parseKVPair(file, key, buffer, delimiter);
}

pub fn getenv(name: []const u8, buffer: []u8) ?[]const u8 {
    var file_descriptor = std.fs.cwd().openFile(".env", .{}) catch |e| {
        switch (e) {
            error.FileNotFound => {
                warn("Unable to find .env in current working directory, resorting to environment variable !", .{}) catch {};
            },
            error.AccessDenied => {
                warn("Missing read permission for .env file, resorting to environment variable !", .{}) catch {};
            },
            else => {},
        }
        return os.getenv(name);
    };
    defer file_descriptor.close();
    return parseKVPair(file_descriptor.reader(), name, buffer, '=') catch null;
}
