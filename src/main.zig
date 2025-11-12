const std = @import("std");
const colorpng = @import("colorpng");

const chunk = colorpng.chunk;
const ColorType = colorpng.chunk.ColorType;
const Chunk = colorpng.chunk.Chunk;
const IHDR = colorpng.chunk.IHDR;
const Color = colorpng.chunk.Color;

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    // var ihdr = IHDR{
    //     .data = .{
    //         .width = 32,
    //         .height = 32,
    //         .bit_depth = 0,
    //         .color_type = ColorType.True,
    //         .compression_method = 0,
    //         .filter_method = 0,
    //         .interlace_method = 0,
    //     },
    // };

    // const chunks = []Chunk{ihdr};

    // var data: [8]u8 = undefined;
    // @memset(data[0..], 0);
    //
    // // std.mem.writeInt(u32, data[0..4], 1823049, .big);
    // // std.mem.writeInt(u32, data[4..8], 123123, .big);
    //
    // std.debug.print("{any}\n", .{data});

    // const ihdr_data = try ihdr.encode(allocator);
    // defer allocator.free(ihdr_data);
    //
    // std.debug.print("{any}\n", .{ihdr_data});

    // const c = colorpng.chunk.Color{
    //     .r = 0x9c,
    //     .g = 0x9c,
    //     .b = 0xfc,
    // };
    //
    // const code: u24 = @bitCast(c);
    // std.debug.print("color={x}\n", .{code});

    // const colors = [_]Color{
    //     .{.r = 0xff, .g = 0, .b = 0},
    //     .{.r = 0x9c, .g = 0x9c, .b = 0xfc},
    //     .{.r = 0, .g = 0, .b = 0xff},
    // };
    //
    // const color_bytes = std.mem.toBytes(colors);
    // std.debug.print("{any}\n", .{color_bytes});

    // std.debug.print("{d}\n", .{@bitSizeOf(Color)});

    // var colors = [_]Color{
    //     .{ .r = 0xff, .g = 0, .b = 0 },
    //     .{ .r = 0, .g = 0xff, .b = 0 },
    //     .{ .r = 0, .g = 0, .b = 0xff },
    // };
    //
    // var plte_chunk = Chunk{ .PLTE = .{.data = .{.palette = colors[0..]}}};
    // const encoded = try plte_chunk.PLTE.encode(allocator);
    //
    // std.debug.print("{any}\n", .{encoded});

    var hdr = Chunk{ .IHDR = .{ .data = .{
        .width = 1_024,
        .height = 1_024,
        .bit_depth = 1,
        .color_type = ColorType.Indexed,
        .compression_method = 0,
        .filter_method = 0,
        .interlace_method = 0,
    } } };

    var colors = [_]Color{
        .{ .r = 0x9c, .g = 0x9c, .b = 0xfc },
    };

    var plte = Chunk{ .PLTE = .{ .data = .{ .palette = &colors } } };

    var end = Chunk{ .IEND = .{ .data = .{} } };

    var image_data: [1024*1025]u8 = undefined;
    @memset(image_data[0..], 0);


    var dat = Chunk{ .IDAT = .{ .data = .{ .image_data = image_data[0..] } } };

    const total_length = 8 + 12 * 4 + hdr.IHDR.data.length() + plte.PLTE.data.length() + dat.IDAT.data.length() + end.IEND.data.length();

    std.debug.print("png size: {d}\n", .{total_length});

    const hdr_data = try hdr.IHDR.encode(allocator);
    const plte_data = try plte.PLTE.encode(allocator);
    const dat_data = try dat.IDAT.encode(allocator);
    const end_data = try end.IEND.encode(allocator);

    defer allocator.free(hdr_data);
    defer allocator.free(plte_data);
    defer allocator.free(dat_data);
    defer allocator.free(end_data);

    var image: []u8 = try allocator.alloc(u8, total_length);
    defer allocator.free(image);

    var s = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

    const data = [_][]u8{
        s[0..],
        hdr_data,
        plte_data,
        dat_data,
        end_data,
    };

    var start: usize = 0;
    for (data) |d| {
        @memcpy(image[start .. start + d.len], d[0..]);
        start += d.len;
    }

    try std.fs.cwd().writeFile(.{
        .data = image[0..],
        .sub_path = "output_image.png",
        .flags = .{},
    });
}

// 0000000d4948445200001f1c000003ac08060000006421e671
