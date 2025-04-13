const std = @import("std");
const Allocator = std.mem.Allocator;

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const numbers_symb = "0123456789+/";
        return Base64{
            ._table = upper ++ lower ++ numbers_symb,
        };
    }

    fn _char_at(self: Base64, index: usize) u8 {
        return self._table[index];
    }

    fn _index_at(self: Base64, char: u8) u8 {
        if (char == '=') {
            return 64;
        }

        var index: u8 = 0;
        for (0..63) |i| {
            if (self._char_at(i) == char) {
                break;
            }
            index += 1;
        }
        return index;
    }

    fn calc_decode_length(input: []const u8) !usize {
        if (input.len < 4) {
            const n_output: usize = 3;
            return n_output;
        }
        const n_output: usize = try std.math.divFloor(usize, input.len, 4);
        return n_output * 3;
    }

    fn calc_encode_length(input: []const u8) !usize {
        if (input.len < 3) {
            return 4;
        }
        const opt: usize = try std.math.divCeil(usize, input.len, 3);
        return opt * 4;
    }

    pub fn encode(self: Base64, allocator: Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        const outLen = try calc_encode_length(input);
        var out = try allocator.alloc(u8, outLen);
        var buf = [_]u8{ 0, 0, 0 };
        var count: u8 = 0;
        var outIndex: u64 = 0;

        for (input) |byte| {
            buf[count] = byte;
            count += 1;
            if (count == 3) {
                // shift right 2 bits to get 00nnnnnn
                out[outIndex] = self._char_at(buf[0] >> 2);
                // and on the last 2 bits of the byte shift left 4 to create null spaces for the first for of the second which is
                // created by shifting it right 4 bits.
                out[outIndex + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
                //need the last 4 of the second byte and the first 2 of the third. the and operation leaves 00001111 where the 1's are the
                // actual which we then shift left 2 and add the buffer that is shifted right 6
                out[outIndex + 2] = self._char_at(((buf[1] & 0x0F) << 2) + (buf[2] >> 6));
                // this just gets the last 6
                out[outIndex + 3] = self._char_at(buf[2] & 0x3F);
                outIndex = outIndex + 4;
                count = 0;
            }
        }

        if (count == 2) {
            out[outIndex] = self._char_at(buf[0] >> 2);
            out[outIndex + 1] = self._char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
            out[outIndex + 2] = self._char_at(((buf[1] & 0x0F) << 2));
            out[outIndex + 3] = '=';
        }

        if (count == 1) {
            out[outIndex] = self._char_at(buf[0] >> 2);
            out[outIndex + 1] = self._char_at((buf[0] & 0x03) << 4);
            out[outIndex + 2] = '=';
            out[outIndex + 3] = '=';
        }

        return out;
    }

    pub fn decode(self: Base64, allocator: Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        const outLen = try calc_decode_length(input);
        const out = try allocator.alloc(u8, outLen);

        var count: u8 = 0;
        var outIndex: u8 = 0;
        var buffer = [_]u8{ 0, 0, 0, 0 };

        for (input) |char| {
            buffer[count] = self._index_at(char);
            count = count + 1;
            if (count == 4) {
                out[outIndex] = (buffer[0] << 2) + (buffer[1] >> 4);
                if (buffer[2] != 64) {
                    out[outIndex + 1] = (buffer[1] << 4) + (buffer[2] >> 2);
                }
                if (buffer[3] != 64) {
                    out[outIndex + 2] = (buffer[2] << 6) + buffer[3];
                }
                outIndex += 3;
                count = 0;
            }
        }

        return out;
    }
};

pub fn main() !void {
    var memory_buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory_buffer);
    const allocator = fba.allocator();
    const base64 = Base64.init();
    const text = "Testing some more stuff";
    const etext = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";
    const encoded_text = try base64.encode(allocator, text);
    const decoded_text = try base64.decode(allocator, etext);
    std.debug.print("Encoded text: {s}\n", .{encoded_text});
    std.debug.print("Decoded text: {s}\n", .{decoded_text});
}
