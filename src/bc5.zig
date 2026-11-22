//! BC5: two 8-bit channels in 16 bytes per 4x4 block (tangent-space normals).

const std = @import("std");
const assert = std.debug.assert;
const bc4 = @import("bc4.zig");
const image = @import("image.zig");

pub const block_bytes = 16;

/// Encodes 16 two-channel pixels; each channel is an independent BC4 block.
pub fn encodeBlock(pixels: *const [16][2]u8) [block_bytes]u8 {
    var r: [16]u8 = undefined;
    var g: [16]u8 = undefined;
    for (pixels, &r, &g) |p, *rv, *gv| {
        rv.* = p[0];
        gv.* = p[1];
    }
    return bc4.encodeBlock(&r) ++ bc4.encodeBlock(&g);
}

pub fn decodeBlock(block: *const [block_bytes]u8) [16][2]u8 {
    const r: @Vector(16, u8) = bc4.decodeBlock(block[0..8]);
    const g: @Vector(16, u8) = bc4.decodeBlock(block[8..16]);
    const pairs: [32]u8 = @shuffle(u8, r, g, alternate);
    return @bitCast(pairs);
}

/// Decodes a signed block (BC5_SNORM): two BC4_SNORM blocks, each value in
/// -127 to 127.
pub fn decodeBlockSnorm(block: *const [block_bytes]u8) [16][2]i8 {
    const r: @Vector(16, i8) = bc4.decodeBlockSnorm(block[0..8]);
    const g: @Vector(16, i8) = bc4.decodeBlockSnorm(block[8..16]);
    const pairs: [32]i8 = @shuffle(i8, r, g, alternate);
    return @bitCast(pairs);
}

/// The shuffle mask that alternates red and green: r0, g0, r1, g1 and so on.
const alternate = mask: {
    var m: [32]i32 = undefined;
    for (0..16) |i| {
        m[2 * i] = i;
        m[2 * i + 1] = ~@as(i32, i);
    }
    break :mask m;
};

/// A signed value from -127 to 127 as the byte of the usual normal-map
/// convention, where a byte u stands for 2 * u / 255 - 1: the byte nearest
/// (s / 127 + 1) / 2 * 255 = (s + 127) * 255 / 254, halves rounded up.
/// texcomp computes it in `f32`, which gives the same bytes: the one half,
/// at s = 0, is exact in `f32`, and every other value lies at least 1 / 254
/// from a half.
fn unormFromSnorm(s: @Vector(16, i8)) @Vector(16, u8) {
    const Wide = @Vector(16, u16);
    const signed: @Vector(16, i16) = @intCast(s);
    const from_zero: Wide = @intCast(signed + @as(@Vector(16, i16), @splat(127)));
    const sum = from_zero * @as(Wide, @splat(255)) + @as(Wide, @splat(127));
    return @intCast(sum / @as(Wide, @splat(254)));
}

/// Encodes channels 0 and 1 of `src` into `dst`, which must hold
/// `image.encodedLen(block_bytes, width, height)` bytes.
pub fn encodeImage(src: image.Image(u8), dst: []u8) void {
    encodeImageRows(src, dst, image.BlockRows.all(src.height));
}

/// `encodeImage` for the block rows `rows` only; see `image.BlockRows`.
pub fn encodeImageRows(src: image.Image(u8), dst: []u8, rows: image.BlockRows) void {
    src.check();
    assert(src.channels >= 2);
    image.encodeBlocks(block_bytes, src.width, src.height, dst, rows, src, struct {
        fn f(s: image.Image(u8), bx: u32, by: u32) [block_bytes]u8 {
            return encodeBlock(&s.block(2, bx, by));
        }
    }.f);
}

/// Decodes into channels 0 and 1 of `dst`; other channels are left untouched.
pub fn decodeImage(src: []const u8, dst: image.ImageMut(u8)) void {
    decodeImageRows(src, dst, image.BlockRows.all(dst.height));
}

/// `decodeImage` for the block rows `rows` only; see `image.BlockRows`.
pub fn decodeImageRows(src: []const u8, dst: image.ImageMut(u8), rows: image.BlockRows) void {
    dst.check();
    assert(dst.channels >= 2);
    image.decodeBlocks(block_bytes, dst.width, dst.height, src, rows, dst, struct {
        fn f(out: image.ImageMut(u8), block: *const [block_bytes]u8, bx: u32, by: u32) void {
            putRedGreen(out, bx, by, bc4.decodeBlock(block[0..8]), bc4.decodeBlock(block[8..16]));
        }
    }.f);
}

/// Writes a block's red and green lanes into channels 0 and 1 of `out`,
/// leaving the other channels as they were. A block wholly inside an image
/// of 2 or 4 channels is written a row of 4 pixels at a time, from the
/// lanes; any other goes through `putBlock`.
fn putRedGreen(out: image.ImageMut(u8), bx: u32, by: u32, r: @Vector(16, u8), g: @Vector(16, u8)) void {
    const inside = (bx + 1) * 4 <= out.width and (by + 1) * 4 <= out.height;
    if (inside and (out.channels == 2 or out.channels == 4)) {
        inline for (0..4) |yy| {
            const at = @as(usize, by * 4 + yy) * out.stride + @as(usize, bx) * 4 * out.channels;
            if (out.channels == 2) {
                out.pixels[at..][0..8].* = @shuffle(u8, r, g, rowPairs(yy));
            } else {
                const row = out.pixels[at..][0..16];
                const pairs: @Vector(16, u8) = @shuffle(u8, r, g, rowQuads(yy));
                row.* = @select(u8, red_green_of_rgba, pairs, @as(@Vector(16, u8), row.*));
            }
        }
        return;
    }
    const pairs: [32]u8 = @shuffle(u8, r, g, alternate);
    out.putBlock(2, bx, by, @ptrCast(&pairs));
}

/// Row `yy` of the block as pixels of two channels: r, g, r, g and so on.
fn rowPairs(comptime yy: usize) [8]i32 {
    var m: [8]i32 = undefined;
    for (0..4) |x| {
        m[2 * x] = yy * 4 + x;
        m[2 * x + 1] = ~@as(i32, yy * 4 + x);
    }
    return m;
}

/// Row `yy` of the block in the red and green bytes of four-channel pixels;
/// the blue and alpha lanes repeat red and green and are not stored.
fn rowQuads(comptime yy: usize) [16]i32 {
    var m: [16]i32 = undefined;
    for (0..4) |x| {
        m[4 * x] = yy * 4 + x;
        m[4 * x + 1] = ~@as(i32, yy * 4 + x);
        m[4 * x + 2] = yy * 4 + x;
        m[4 * x + 3] = ~@as(i32, yy * 4 + x);
    }
    return m;
}

const red_green_of_rgba: @Vector(16, bool) = .{ true, true, false, false, true, true, false, false, true, true, false, false, true, true, false, false };

/// Decodes signed blocks (BC5_SNORM) into channels 0 and 1 of `dst`, as
/// bytes in the usual normal-map convention, where a byte u stands for
/// 2 * u / 255 - 1: -127 gives 0, 0 gives 128 and 127 gives 255. Other
/// channels are left untouched.
pub fn decodeImageSnorm(src: []const u8, dst: image.ImageMut(u8)) void {
    decodeImageSnormRows(src, dst, image.BlockRows.all(dst.height));
}

/// `decodeImageSnorm` for the block rows `rows` only; see `image.BlockRows`.
pub fn decodeImageSnormRows(
    src: []const u8,
    dst: image.ImageMut(u8),
    rows: image.BlockRows,
) void {
    dst.check();
    assert(dst.channels >= 2);
    image.decodeBlocks(block_bytes, dst.width, dst.height, src, rows, dst, struct {
        fn f(out: image.ImageMut(u8), block: *const [block_bytes]u8, bx: u32, by: u32) void {
            const r = unormFromSnorm(bc4.decodeBlockSnorm(block[0..8]));
            const g = unormFromSnorm(bc4.decodeBlockSnorm(block[8..16]));
            putRedGreen(out, bx, by, r, g);
        }
    }.f);
}
