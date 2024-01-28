const std = @import("std");
const zap = @import("zap");

const fs = std.fs;
const os = std.os;
const system = os.system;
const print = std.debug.print;

const str = []const u8;
const DEFAULT_PORT = 3040;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = gpa.allocator();

// TODO: Parse build.zig.zon at compile time to get version
const SERVER_VERSION = "v0.0.0";

const CPUSample = struct {
    user: u64,
    nice: u64,
    system: u64,
    idle: u64,
    // iowait: u64,
    // irq: u64,
    // softirq: u64,
    // steal: u64,
    // guest: u64,
    // guest_nice: u64,
};

const CPUInfo = struct {
    usage: u7, // percentage, cannot exceed 100
    arch: str,
    model: str,
};

const OSInfo = struct {
    type: str,
    platform: str,
    version: str,
    release: str,
};

const softwareInfo = struct { version: str = SERVER_VERSION };

const RAMInfo = struct {
    percent: u7, // shouldn't exceed 100, the smallest integer that can fit 100 is a u7
    free: u32, // supports up to 4TB of ram
    max: u32,
};

// const Infos = struct {
//     serverVersion: str,
//     serverId: str,
//     serverUptime: i64,
//     serverHostname: str,
//     cpuUsage: u7,
//     cpuArch: str,
//     cpuName: str,
//     ramPercent: u7,
//     ramFree: u32, // support up to 4TB of RAM
//     ramMax: u32,
//     osType: str,
//     osPlatform: str,
//     osVersion: str,
//     osRelease: str,
// };

const ServerInfo = struct {
    id: str,
    uptime: i64,
    hostname: str,
    cpu: ?CPUInfo,
    ram: ?RAMInfo,
    os: ?OSInfo,
};

const Infos = struct { software: softwareInfo, server: ServerInfo };

fn parse_proc_info(comptime path: str, key: str, buf: []u8, max_it: ?u8) ?[]const u8 {
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

fn parse_cpustat_fields(field_line: []u8) CPUSample {
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

fn get_cpu_sample() ?CPUSample {
    // SEE: https://stackoverflow.com/questions/11356330/how-to-get-cpu-usage
    // SEE: https://www.baeldung.com/linux/get-cpu-usage
    var buf: [200]u8 = undefined;

    var fileDescriptor = fs.openFileAbsolute("/proc/stat", .{ .intended_io_mode = .blocking }) catch return null;

    defer fileDescriptor.close();
    const file = fileDescriptor.reader();
    const line = (file.readUntilDelimiter(&buf, '\n') catch return null)[5..];
    const stats = parse_cpustat_fields(line);

    // print("{s}\n{any}", .{ line, stats });
    return stats;
}

fn get_cpu_percent(sampleTime: ?u12) ?u7 {
    const timeToWait: u64 = std.time.ns_per_ms * @as(u64, @intCast((sampleTime orelse 100)));
    const sample1 = get_cpu_sample() orelse return null;
    std.time.sleep(timeToWait);
    const sample2 = get_cpu_sample() orelse return null;

    const sample1TotalTicks = tick: {
        var total: u64 = 0;
        total += sample1.user;
        total += sample1.nice;
        total += sample1.system;

        break :tick total;
    };

    const sample2TotalTicks = tick: {
        var total: u64 = 0;
        total += sample2.user;
        total += sample2.nice;
        total += sample2.system;

        break :tick total;
    };

    const totalTicks = @abs(sample2TotalTicks - sample1TotalTicks);
    const idleTicks = @abs(sample2.idle - sample1.idle);

    const percent = @as(f128, @floatFromInt(totalTicks)) / (@as(f128, @floatFromInt(idleTicks)) + (@as(f128, @floatFromInt(totalTicks)))) * 100;

    return @intFromFloat(@trunc(percent));
}

fn get_load_avg() str {
    // https://fr.wikipedia.org/wiki/Load_average
    return "TODO";
}

fn getRAMStats() ?RAMInfo {
    var buff: [50]u8 = undefined;
    var buf2: [50]u8 = undefined;
    const mem_total_str = parse_proc_info("/proc/meminfo", "MemTotal", &buff, null);
    const mem_available_str = parse_proc_info("/proc/meminfo", "MemAvailable", &buf2, null);

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

fn get_uptime() i64 {
    var ts: os.timespec = undefined;
    os.clock_gettime(os.linux.CLOCK.BOOTTIME, &ts) catch unreachable;
    return @as(i64, ts.tv_sec);
}

fn trim_zeros_right(value: *[64:0]u8) []u8 {
    return value[0..std.mem.indexOfScalar(u8, value, 0).?];
}

fn process_request(request: zap.SimpleRequest) void {
    if (!(request.method == null) and !std.mem.eql(u8, request.method.?, "GET") or (!(request.path == null) and !std.mem.eql(u8, request.path.?, "/api"))) {
        request.setStatus(.not_found);
        request.sendJson("{\"Error\":\"BAD REQUEST\"}") catch return;
        return;
    }

    var requestBody: []const u8 = undefined;
    var cpuInfoBuff: [256]u8 = undefined;
    var uname = os.uname();

    const systemInfo = Infos{
        .software = softwareInfo{},
        .server = ServerInfo{
            .id = os.getenv("SERVER_NAME") orelse "Unnamed server",
            .uptime = get_uptime(),
            .hostname = trim_zeros_right(&uname.nodename),
            .cpu = CPUInfo{
                .usage = get_cpu_percent(null) orelse 0,
                .arch = trim_zeros_right(&uname.machine),
                .model = parse_proc_info("/proc/cpuinfo", "model name", &cpuInfoBuff, null) orelse "Unable to query CPU Name",
            },
            .ram = getRAMStats(),
            .os = OSInfo{
                .type = trim_zeros_right(&uname.sysname),
                .platform = trim_zeros_right(&uname.sysname), // basically the same as the OS type
                .version = trim_zeros_right(&uname.version),
                .release = trim_zeros_right(&uname.release),
            },
        },
    };

    requestBody = std.json.stringifyAlloc(alloc, systemInfo, .{}) catch "{\"Error\":\"Unable to generate JSON\"}";

    // std.debug.print("{s}\n", .{requestBody});
    request.sendJson(requestBody) catch return;
}

pub fn main() !void {
    const port = p: {
        const env = os.getenv("PORT");
        if (env == null) break :p DEFAULT_PORT;
        break :p std.fmt.parseUnsigned(usize, env.?, 10) catch DEFAULT_PORT;
    };

    var server = zap.SimpleHttpListener.init(.{
        .port = port,
        .on_request = process_request,
        .log = false,
    });

    try server.listen();
    std.debug.print("Started on port {any}\n", .{@as(u16, @truncate(port))});

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
