const std = @import("std");

const fs = std.fs;
const os = std.os;
const system = os.system;
const print = std.debug.print;

const str = []const u8;

const CPUSample = struct {
    /// Time spent in user mode
    user: u64,
    /// Time spent processing niced processes
    nice: u64,
    /// Time spent in system mode
    system: u64,
    /// Time spend idling
    idle: u64,
    // iowait: u64,
    // irq: u64,
    // softirq: u64,
    // steal: u64,
    // guest: u64,
    // guest_nice: u64,
};

pub const CPUInfo = struct {
    usage: u7, // percentage, cannot exceed 100
    /// CPU Archicture
    arch: str,
    /// CPU Model and speed
    model: str,
};

pub const OSInfo = struct {
    type: str,
    platform: str,
    version: str,
    release: str,
};

pub const RAMStat = struct {
    percent: u7, // shouldn't exceed 100, the smallest integer that can fit 100 is a u7
    free: u32, // supports up to 4TB of ram
    max: u32,
};

/// get time since boot in second
pub fn getUptime() i64 {
    var ts: os.timespec = undefined;
    os.clock_gettime(os.linux.CLOCK.BOOTTIME, &ts) catch unreachable;
    return @as(i64, ts.tv_sec);
}

/// Query /proc/meminfo or /proc/cpuinfo for specific values
/// @param path: <comptime string>
pub fn parseProcInfo(comptime path: str, key: str, buf: []u8, max_it: ?u8) ?str {
    var i: u8 = 0;
    var fbs = std.io.fixedBufferStream(buf);
    var fileDescriptor = fs.openFileAbsolute(path, .{ .intended_io_mode = .blocking }) catch |err| switch (err) {
        error.FileNotFound => return "Error: No " ++ path,
        else => return "Error openning " ++ path,
    };

    defer fileDescriptor.close();
    const file = fileDescriptor.reader();

    while (i < (max_it orelse 10)) : (i += 1) {
        defer fbs.reset();
        file.streamUntilDelimiter(fbs.writer(), '\n', null) catch return null;
        const written = fbs.getWritten();
        if (written.len < key.len) continue;
        // std.debug.print("{s}\n", .{written});
        if (std.mem.eql(u8, written[0..key.len], key)) {
            const colon_pos = std.mem.indexOfScalar(u8, written, ':').?;
            return std.mem.trimLeft(u8, written[colon_pos + 2 ..], " ");
        }
    }
    return null;
}

fn parseCPUStatFields(field_line: []u8) CPUSample {
    var it = std.mem.splitScalar(u8, field_line, ' ');
    var result: CPUSample = undefined;
    // TODO: Optimise using metaprogramming
    result.user = std.fmt.parseUnsigned(u64, it.first(), 10) catch unreachable;
    result.nice = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    result.system = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    result.idle = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    // result.iowait = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    // result.irq = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    // result.softirq = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    // result.steal = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    // result.guest = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;
    // result.guest_nice = std.fmt.parseUnsigned(u64, it.next().?, 10) catch unreachable;

    return result;
}

fn getCPUSample() ?CPUSample {
    // SEE: https://stackoverflow.com/questions/11356330/how-to-get-cpu-usage
    // SEE: https://www.baeldung.com/linux/get-cpu-usage
    var buf: [200]u8 = undefined;

    var file_descriptor = fs.openFileAbsolute("/proc/stat", .{ .intended_io_mode = .blocking }) catch return null;

    defer file_descriptor.close();
    const file = file_descriptor.reader();
    const line = (file.readUntilDelimiter(&buf, '\n') catch return null)[5..];
    const stats = parseCPUStatFields(line);

    // print("{s}\n{any}", .{ line, stats });
    return stats;
}

/// Query system for CPU Usage
/// Returns an integer in between 0 and 100
pub fn getCPUPercent(sampleTime: ?u12) ?u7 {
    const time_to_wait: u64 = std.time.ns_per_ms * @as(u64, @intCast((sampleTime orelse 100)));
    const sample1 = getCPUSample() orelse return null;
    std.time.sleep(time_to_wait);
    const sample2 = getCPUSample() orelse return null;

    const sample1_total_ticks = tick: {
        var total: u64 = 0;
        total += sample1.user;
        total += sample1.nice;
        total += sample1.system;

        break :tick total;
    };

    const sample2_total_ticks = tick: {
        var total: u64 = 0;
        total += sample2.user;
        total += sample2.nice;
        total += sample2.system;

        break :tick total;
    };

    const total_ticks = @abs(sample2_total_ticks - sample1_total_ticks);
    const idle_ticks = @abs(sample2.idle - sample1.idle);

    const percent = @as(f128, @floatFromInt(total_ticks)) / (@as(f128, @floatFromInt(idle_ticks)) + (@as(f128, @floatFromInt(total_ticks)))) * 100;

    return @intFromFloat(@trunc(percent));
}

/// Query RAM Information such as
/// - available memory
/// - available total
/// - RAM usage as percentage
pub fn getRAMStats() ?RAMStat {
    var buff: [50]u8 = undefined;
    var buf2: [50]u8 = undefined;
    const mem_total_str = parseProcInfo("/proc/meminfo", "MemTotal", &buff, null);
    const mem_available_str = parseProcInfo("/proc/meminfo", "MemAvailable", &buf2, null);

    if (mem_total_str == null or mem_available_str == null) return null;

    const mem_total = std.fmt.parseUnsigned(u26, mem_total_str.?[0 .. mem_total_str.?.len - 3], 10) catch return null;
    const mem_available = std.fmt.parseUnsigned(u26, mem_available_str.?[0 .. mem_available_str.?.len - 3], 10) catch return null;
    const percent: u7 = @intFromFloat(@floor((@as(f32, @floatFromInt(mem_available)) / @as(f32, @floatFromInt(mem_total)) * 100)));

    return .{
        .percent = percent,
        .free = mem_available,
        .max = mem_total,
    };
}
