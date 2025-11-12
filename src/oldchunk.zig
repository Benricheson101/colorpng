const std = @import("std");
const Allocator = std.mem.Allocator;
const Crc32 = std.hash.Crc32;
const zstd = std.compress.zstd;

const comprezz = @import("comprezz.zig");

pub const Chunk = union {
    /// Image header chunk
    IHDR: IHDR,
    PLTE: PLTE,
    IDAT: IDAT,
    IEND: IEND,
};

pub const IHDR = PNGChunk(.{ 73, 72, 68, 82 }, IHDRData);
pub const PLTE = PNGChunk(.{ 80, 76, 84, 69 }, PLTEData);
pub const IEND = PNGChunk(.{ 73, 69, 78, 68 }, IENDData);
pub const IDAT = PNGChunk(.{ 73, 68, 65, 84 }, IDATData);

// TODO: does this have anything to do with endianess? the docs make it look like it may but someone on reddit said that was a mistake

// for some reason the backing integer has struct fields in reverse order
pub const Color = packed struct(u24) {
    b: u8,
    g: u8,
    r: u8,
};

/// A generic PNG chunk
///
/// 4 bytes: data length
/// 4 bytes: chunk type
/// ? bytes: data
/// 4 bytes: crc32
fn PNGChunk(comptime chunk_typ: [4]u8, comptime Data: type) type {
    const BASE_CHUNK_SIZE: usize = 12;

    return struct {
        data: Data,

        const Self = @This();

        pub fn encode(self: *Self, allocator: Allocator) ![]u8 {
            const data_length: u32 = self.data.length();
            const buf = try allocator.alloc(u8, BASE_CHUNK_SIZE + data_length);

            // pub fn encode(self: *Self, buf: []u8) !usize {
            //     const data_length: u32 = self.data.length();
            //     // const buf = try allocator.alloc(u8, BASE_CHUNK_SIZE + data_length);
            @memset(buf[0..], 0);

            std.mem.writeInt(u32, buf[0..4], data_length, .big);
            // TODO: should this be memmove? waht's the difference in this case
            @memcpy(buf[4..8], chunk_typ[0..4]);

            _ = try self.data.encode(buf[8 .. buf.len - 4]);

            const crc = Crc32.hash(buf[4 .. buf.len - 4]);
            // FIXME: why doesn't this one work?
            // std.mem.writeInt(u32, buf[buf.len - 4 .. buf.len], crc, .big);
            std.mem.writePackedInt(u32, buf[buf.len - 4 ..], 0, crc, .big);

            return buf;
            //
            // return BASE_CHUNK_SIZE + data_length;
        }
    };
}

pub const ColorType = enum(u8) {
    /// allowed bit depths: 1, 2, 4, 8, 16
    Grayscale = 0,
    /// allowed bit depths: 8, 16
    True = 2,
    /// allowed bit depths: 1, 2, 4, 8
    Indexed = 3,
    /// allowed bit depths: 8, 16
    GrayscaleAlpha = 4,
    /// allowed bit depths: 8, 16
    TrueAlpha = 6,
};

pub const IHDRData = struct {
    /// width of the image
    width: u32,
    /// height of the image
    height: u32,
    /// number of bits per sample (r/g/b) or per palette index (not per pixel). one of: 1, 2, 4, 8, 16
    bit_depth: u8,
    color_type: ColorType,
    /// 0: deflate/inflate
    compression_method: u8,
    filter_method: u8,
    interlace_method: u8,

    pub fn length(_: *IHDRData) u32 {
        return 13;
    }

    fn encode(self: *IHDRData, buf: []u8) !usize {
        std.mem.writeInt(u32, buf[0..4], self.width, .big);
        std.mem.writeInt(u32, buf[4..8], self.height, .big);
        buf[8] = self.bit_depth;
        buf[9] = @intFromEnum(self.color_type);
        buf[10] = self.compression_method;
        buf[11] = self.filter_method;
        buf[12] = self.interlace_method;

        return 13;
    }
};

pub const PLTEData = struct {
    palette: []Color,

    pub fn length(self: *PLTEData) u32 {
        const len: u32 = @intCast(self.palette.len);
        return len * 3;
    }

    fn encode(self: *PLTEData, buf: []u8) !usize {
        for (self.palette, 0..) |color, i| {
            const bytes: u24 = @bitCast(color);
            std.mem.writePackedInt(u24, buf[(i * 3) .. (i * 3) + 3], 0, bytes, .big);
        }

        return self.palette.len * 3;
    }
};

pub const IENDData = struct {
    pub fn length(_: *IENDData) u32 {
        return 0;
    }

    fn encode(_: *IENDData, _: []u8) !usize {
        return 0;
    }
};

pub const IDATData = struct {
    image_data: []u8,

    pub fn length(self: *IDATData) u32 {
        return @intCast(self.image_data.len);
    }

    fn encode(self: *IDATData, buf: []u8) !usize {
        // FIXME: pass this in as an arg
        // const allocator = std.heap.smp_allocator;

        var str = std.io.fixedBufferStream(self.image_data);
        // var reader = str.reader();
        var str_buf: [1024]u8 = std.mem.zeroes([1024]u8);
        var reader = str.reader().adaptToNewApi(str_buf[0..]).new_interface;

        // const deflate_buf = try allocator.alloc(u8, 10 * (zstd.default_window_len + zstd.block_size_max));
        // defer allocator.free(deflate_buf);

        // const d = std.compress.flate.Decompress.init(&reader, .zlib, deflate_buf);
        // var df_reader: std.io.Reader = d.reader;
        // _ = try df_reader.readSliceShort(buf[0..]);
        // const read = try df_reader.allocRemaining(allocator, .unlimited);
        // return read;

        var writer = std.io.Writer.fixed(buf[0..]);

        try comprezz.compress(&reader, &writer, .{});

        // Find the end of compressed data by checking for non-zero bytes
        var written: usize = 0;
        for (buf, 0..) |byte, i| {
            if (byte != 0) written = i + 1;
        }
        return written;
        // const compressed = buf[0..written];
        // _ = compressed;

        // // var s = try std.compress.flate.Compress.Simple.init(&writer, data[0..], .zlib, .huffman);
        // try s.flush();
        // try s.finish();

        // @memcpy(buf[0..], self.image_data[0..]);
    }
};

test "color packed struct" {
    const color = Color{ .r = 0x9c, .g = 0x9c, .b = 0xfc };

    const as_int: u24 = @bitCast(color);
    try std.testing.expectEqual(as_int, 0x9c9cfc);
}
