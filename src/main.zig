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

const SoftwareInfo = struct { version: str = SERVER_VERSION };

const RAMStat = struct {
    percent: u7, // shouldn't exceed 100, the smallest integer that can fit 100 is a u7
    free: u32, // supports up to 4TB of ram
    max: u32,
};

const ServerInfo = struct {
    id: str,
    uptime: i64,
    hostname: str,
    cpu: ?CPUInfo,
    ram: ?RAMStat,
    os: ?OSInfo,
};

const Infos = struct { software: SoftwareInfo, server: ServerInfo };

fn parseProcInfo(comptime path: str, key: str, buf: []u8, max_it: ?u8) ?[]const u8 {
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

fn getCPUPercent(sampleTime: ?u12) ?u7 {
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

fn getLoadAverage() str {
    // https://fr.wikipedia.org/wiki/Load_average
    return "TODO";
}

fn getRAMStats() ?RAMStat {
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

fn getUptime() i64 {
    var ts: os.timespec = undefined;
    os.clock_gettime(os.linux.CLOCK.BOOTTIME, &ts) catch unreachable;
    return @as(i64, ts.tv_sec);
}

fn trimZerosRight(value: *[64:0]u8) []u8 {
    return value[0..std.mem.indexOfScalar(u8, value, 0).?];
}

fn processRequest(request: zap.SimpleRequest) void {
    if (!(request.method == null) and !std.mem.eql(u8, request.method.?, "GET") or (!(request.path == null) and !std.mem.eql(u8, request.path.?, "/api"))) {
        request.setStatus(.not_found);
        request.sendJson("{\"Error\":\"BAD REQUEST\"}") catch return;
        return;
    }

    // looks like getHeader is broken on this version of zap
    // const auth_header = request.getHeader("Authorization");
    // if (auth_header == null or !std.mem.eql(u8, auth_header.?, os.getenv("PASSWORD").?)) {
    //     request.setStatus(.forbidden);
    //     print("{?u}", .{auth_header});
    //     print("{any}", .{request});
    //     request.sendJson("{\"Error\":\"UNAUTHORIZED\"}") catch return;
    //     return;
    // }

    var request_body: []const u8 = undefined;
    var cpu_info_buff: [256]u8 = undefined;
    var uname = os.uname();

    const system_info = Infos{
        .software = SoftwareInfo{},
        .server = ServerInfo{
            .id = os.getenv("SERVER_NAME") orelse "Unnamed server",
            .uptime = getUptime(),
            .hostname = trimZerosRight(&uname.nodename),
            .cpu = CPUInfo{
                .usage = getCPUPercent(null) orelse 0,
                .arch = trimZerosRight(&uname.machine),
                .model = parseProcInfo("/proc/cpuinfo", "model name", &cpu_info_buff, null) orelse "Unable to query CPU Name",
            },
            .ram = getRAMStats(),
            .os = OSInfo{
                .type = trimZerosRight(&uname.sysname),
                .platform = trimZerosRight(&uname.sysname), // basically the same as the OS type
                .version = trimZerosRight(&uname.version),
                .release = trimZerosRight(&uname.release),
            },
        },
    };

    request_body = std.json.stringifyAlloc(alloc, system_info, .{}) catch "{\"Error\":\"Unable to generate JSON\"}";

    // std.debug.print("{s}\n", .{requestBody});
    request.sendJson(request_body) catch return;
}

pub fn main() !void {
    const port = p: {
        const env = os.getenv("PORT");
        if (env == null) break :p DEFAULT_PORT;
        break :p std.fmt.parseUnsigned(usize, env.?, 10) catch DEFAULT_PORT;
    };
    var server = zap.SimpleHttpListener.init(.{
        .port = port,
        .on_request = processRequest,
        .log = false,
    });

    try server.listen();
    std.debug.print("Started on port {any}\n", .{@as(u16, @truncate(port))});

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
