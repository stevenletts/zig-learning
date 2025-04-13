const std = @import("std");
const SocketConf = @import("config.zig");


pub fn main() !void {
    const socket = try SocketConf.Socket.init();
    const stdOutWriter = std.io.getStdOut().writer();
    try stdOutWriter.print("Server Addr: {any}\n", .{socket._address});
    var server = try socket._address.listen(.{});
    const connection = try server.accept();
    _ = connection;
}