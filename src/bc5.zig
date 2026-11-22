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
/// writing no other byte. A block wholly inside an image of 2 or 4 channels
/// is written from the lanes, a row or a pixel's two bytes at a time; any
/// other goes through `putBlock`.
fn putRedGreen(out: image.ImageMut(u8), bx: u32, by: u32, r: @Vector(16, u8), g: @Vector(16, u8)) void {
    const inside = out.width - bx * 4 >= 4 and out.height - by * 4 >= 4;
    if (inside and (out.channels == 2 or out.channels == 4)) {
        // Each pixel's red and green as one 16-bit lane, in pixel order.
        const pairs: @Vector(16, u16) = @bitCast(@as(@Vector(32, u8), @shuffle(u8, r, g, alternate)));
        inline for (0..4) |yy| {
            const at = @as(usize, by * 4 + yy) * out.stride + @as(usize, bx) * 4 * out.channels;
            if (out.channels == 2) {
                out.pixels[at..][0..8].* = @bitCast(@as(@Vector(4, u16), @shuffle(u16, pairs, undefined, [4]i32{ yy * 4, yy * 4 + 1, yy * 4 + 2, yy * 4 + 3 })));
            } else {
                // Only red and green are written: another thread may own
                // blue and alpha.
                inline for (0..4) |x| out.pixels[at + 4 * x ..][0..2].* = @bitCast(pairs[yy * 4 + x]);
            }
        }
        return;
    }
    const pairs: [32]u8 = @shuffle(u8, r, g, alternate);
    out.putBlock(2, bx, by, @ptrCast(&pairs));
}

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
