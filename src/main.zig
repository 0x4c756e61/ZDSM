const std = @import("std");
const zap = @import("zap");
const oss = @import("os-stats");
const utils = @import("utils");

const os = std.os;
const print = std.debug.print;
const mem = std.mem;
const fmt = std.fmt;
const json = std.json;

const CPUInfo = oss.CPUInfo;
const RAMStat = oss.RAMStat;
const OSInfo = oss.OSInfo;

const str = []const u8;
const banner = @embedFile("banner");

const DEFAULT_PORT = 3040;
const DEFAULT_PASSWORD = "admin";
const DEFAULT_SERVERNAME = "ZDSM";

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var alloc = gpa.allocator();
var ctx: *const Context = undefined;

// TODO: Parse build.zig.zon at compile time to get version
const SERVER_VERSION = "v0.1.0";

const SoftwareInfo = struct { version: str = SERVER_VERSION };

const ServerInfo = struct {
    id: str,
    uptime: i64,
    hostname: str,
    cpu: ?CPUInfo,
    ram: ?RAMStat,
    os: ?OSInfo,
};

const Infos = struct { software: SoftwareInfo, server: ServerInfo };

const Context = struct {
    server_name: str,
    password: str,
};

fn getLoadAverage() str {
    // https://fr.wikipedia.org/wiki/Load_average
    return "TODO";
}

fn trimZerosRight(value: *[64:0]u8) []u8 {
    return value[0..mem.indexOfScalar(u8, value, 0).?];
}

fn processRequest(request: zap.Request) void {
    if (!(request.method == null) and !mem.eql(u8, request.method.?, "GET") or (!(request.path == null) and !mem.eql(u8, request.path.?, "/api"))) {
        request.setStatus(.not_found);
        request.sendJson("{\"Error\":\"BAD REQUEST\"}") catch return;
        utils.warn("Got malformed request: got {?s} /{?s}", .{ request.method, request.path }) catch return;
        return;
    }

    const authenticator = zap.Auth.BearerSingle;
    var auth = authenticator.init(alloc, ctx.password, null) catch return;
    defer auth.deinit();

    const rq = request;
    const ar = auth.authenticateRequest(&rq);

    if (ar != zap.Auth.AuthResult.AuthOK) {
        request.setStatus(.unauthorized);
        request.sendJson("{\"Error\":\"UNAUTHORIZED\"}") catch return;
        utils.warn("Login attempt failed", .{}) catch return;
        return;
    }

    var request_body: []const u8 = undefined;
    var cpu_info_buff: [256]u8 = undefined;
    var uname = os.uname();

    const system_info = Infos{
        .software = SoftwareInfo{},
        .server = ServerInfo{
            .id = ctx.server_name,
            .uptime = oss.getUptime(),
            .hostname = trimZerosRight(&uname.nodename),
            .cpu = CPUInfo{
                .usage = oss.getCPUPercent(null) orelse 0,
                .arch = trimZerosRight(&uname.machine),
                .model = utils.parseKVPairOpenFile("/proc/cpuinfo", "model name", &cpu_info_buff, ':') catch return orelse "Data Unavailable",
            },
            .ram = oss.getRAMStats(),
            .os = OSInfo{
                .type = trimZerosRight(&uname.sysname),
                .platform = trimZerosRight(&uname.sysname), // basically the same as the OS type
                .version = trimZerosRight(&uname.version),
                .release = trimZerosRight(&uname.release),
            },
        },
    };

    request_body = json.stringifyAlloc(alloc, system_info, .{}) catch "{\"Error\":\"Unable to generate JSON\"}";
    request.sendJson(request_body) catch return;
}

pub fn main() !void {
    var password_buff: [50]u8 = undefined;
    var server_name_buff: [50]u8 = undefined;
    var port_buffer: [5]u8 = undefined;

    const password = utils.getenv("PASSWORD", &password_buff) orelse DEFAULT_PASSWORD;
    const server_name = utils.getenv("SERVER_NAME", &server_name_buff) orelse DEFAULT_SERVERNAME;
    const port = p: {
        const env = utils.getenv("PORT", &port_buffer);
        if (env == null) break :p DEFAULT_PORT;
        break :p fmt.parseUnsigned(usize, env.?, 10) catch DEFAULT_PORT;
    };

    ctx = &Context{ .server_name = server_name, .password = password };

    var server = zap.HttpListener.init(.{
        .port = port,
        .on_request = processRequest,
        .log = false,
    });

    print(banner, .{ server_name, SERVER_VERSION, port, password });

    try server.listen();
    try utils.info("Server running on port {any}", .{@as(u16, @truncate(port))});

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
