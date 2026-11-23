//! Recorded digests: the SHA-256 of what every encoder and decoder writes on
//! fixed inputs, so a build for another CPU, OS or optimize mode can be
//! checked against the bytes recorded here, which are those of v0.3.2. The
//! differential tests compare with the originals built for the same machine;
//! these compare across machines. The inputs use fixed seeds, not
//! `-Dfuzz-seed`.

const std = @import("std");
const bcn = @import("bcn");
const images = @import("images.zig");

const Sha = std.crypto.hash.sha2.Sha256;
const W = images.width;
const H = images.height;

fn expectDigest(name: []const u8, want_hex: *const [64]u8, h: *Sha) !void {
    var d: [32]u8 = undefined;
    h.final(&d);
    const got_hex = std.fmt.bytesToHex(d, .lower);
    if (!std.mem.eql(u8, want_hex, &got_hex)) {
        std.debug.print("\n{s}: digest {s}, recorded {s}\n", .{ name, &got_hex, want_hex });
        return error.DigestMismatch;
    }
}

fn ldrView(img: *const images.Ldr) bcn.Image(u8) {
    return bcn.Image(u8).init(std.mem.sliceAsBytes(&img.pixels), W, H, 4);
}

/// Random blocks in styles that make ties, flat channels and alpha.
fn randomBlock(rng: *images.Rng, out: *[16][4]u8) void {
    const style = rng.below(5);
    const base: [4]u8 = .{ rng.byte(), rng.byte(), rng.byte(), rng.byte() };
    for (out, 0..) |*p, i| {
        for (p, 0..) |*c, k| {
            c.* = switch (style) {
                0 => rng.byte(),
                1 => if (rng.below(2) == 0) 0 else 255,
                2 => base[k] +% @as(u8, @intCast(rng.below(5))),
                3 => if (i > 0 and rng.below(3) != 0) out[i - 1][k] else rng.byte(),
                else => base[k],
            };
        }
        if (rng.below(4) == 0) p[3] = 255;
    }
}

fn randomWeight(rng: *images.Rng) u32 {
    return if (rng.below(2) == 0) rng.below(300) else @truncate(rng.next());
}

const bc7_levels = std.enums.values(bcn.bc7.Level);

/// One digest per level and metric, over the image set, RGBA and RGB.
const bc7_image_digests = [bc7_levels.len][2]*const [64]u8{
    .{ "5ef829b4b6e7b17c840fdfba0f1954cd6ef1b7e0240ffbab5a940d34268913cd", "5da27a93df43de9f0ed8c9af8ab1b0cdd0cf69865b62ebf16bcefa437499578d" },
    .{ "18f18a0a8cae4070fb98b4d689e97bb06ccd71444ef1c84d19bb8b9f4814cfcd", "9b5404823ffc9729b1f95631968351a6d3a9a2beecf04ded3286dd6a1d811366" },
    .{ "18f18a0a8cae4070fb98b4d689e97bb06ccd71444ef1c84d19bb8b9f4814cfcd", "5e2ab5b53fbec41ed6bab90fa7ed36f1cfee4a7dd329ef47a62b81b638b10630" },
    .{ "220257f2ae0735973ae28fe020df5a0e287591b7a27e69856c0149ad99b32ac9", "c094f1684e3adabcaa095f24c644838ac12508e82d57e144fd6c956aa93b0d75" },
    .{ "a5de096f863d07c8d7998e04ec70f14826fcfd80dcef9e232ef2a299867aa0aa", "a0d671f5e9011571e14cc366807f4a9c43d157ecfe8de4e6fe789374ea8e7a56" },
    .{ "89c04dea9016b6e0e9601a7f999728636f0ad46917d2c58bb830f03fd0a178d3", "bf7add52db94281bef23c1c28ff8fab6638970e2da5c0263de924fb49c896b78" },
    .{ "c838dd95c2423c8b8484a1150e7d2dfe407eb78f1519fb62eae06ad7d346ecc2", "7fc88eb365a4e010ac9b663342188a224ab2f1126e5385460d81299d4a654ece" },
};

test "bc7 encodes the image set to the recorded bytes at every level" {
    var enc: [bcn.encodedLen(16, W, H)]u8 = undefined;
    var rgb: [images.pixel_count][3]u8 = undefined;
    var failed = false;
    for (bc7_levels, 0..) |level, li| for ([_]bool{ true, false }, 0..) |perceptual, pi| {
        var h = Sha.init(.{});
        const params = bcn.bc7.Params.init(level, perceptual);
        for (0..images.ldr_names.len) |i| {
            const img = images.ldr(i);
            bcn.bc7.encodeImage(ldrView(&img), &enc, &params);
            h.update(&enc);
            for (img.pixels, &rgb) |p, *q| q.* = p[0..3].*;
            bcn.bc7.encodeImage(bcn.Image(u8).init(std.mem.sliceAsBytes(&rgb), W, H, 3), &enc, &params);
            h.update(&enc);
        }
        var name_buf: [64]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buf, "bc7 {s} perceptual={}", .{ @tagName(level), perceptual });
        expectDigest(name, bc7_image_digests[li][pi], &h) catch {
            failed = true;
        };
    };
    if (failed) return error.DigestMismatch;
}

test "bc7 encodes random blocks to the recorded bytes, with any settings" {
    var h = Sha.init(.{});
    var rng: images.Rng = .{ .state = 0x7e57 };
    for (0..3000) |i| {
        var px: [16][4]u8 = undefined;
        randomBlock(&rng, &px);
        var params = bcn.bc7.Params.init(bc7_levels[i % bc7_levels.len], rng.below(2) == 0);
        if (rng.below(3) == 0) params.weights = .{ randomWeight(&rng), randomWeight(&rng), randomWeight(&rng), randomWeight(&rng) };
        if (rng.below(4) == 0) params.use_luts = false;
        if (rng.below(4) == 0) params.alpha_settings.mode67_error_weight_mul = .{ randomWeight(&rng), rng.below(5), rng.below(5), rng.below(5) };
        const e = bcn.bc7.encodeBlockReportingLut(&px, &params);
        h.update(&e.block);
        h.update(&.{@intFromBool(e.used_lut)});
        const mode: u3 = @intCast(rng.below(8));
        const r = bcn.bc7.encodeBlockSingleMode(&px, &params, .{ .mode = mode });
        h.update(&r.block);
        h.update(std.mem.asBytes(&r.err));
    }
    try expectDigest("bc7 random blocks", "1574d1a90d2c4473c8bd2d230f123959130a1f4e3884c8d4c33fe67b357da140", &h);
}

test "bc1 to bc5 and bc6h encode the image sets to the recorded bytes" {
    var enc16: [bcn.encodedLen(16, W, H)]u8 = undefined;
    var enc8: [bcn.encodedLen(8, W, H)]u8 = undefined;
    var h = Sha.init(.{});
    for (0..images.ldr_names.len) |i| {
        const img = images.ldr(i);
        const view = ldrView(&img);
        for ([_]bcn.bc1.Settings{ .{}, .{ .quality = .high }, .{ .rounding = .biased } }) |s| {
            bcn.bc1.encodeImage(view, &enc8, s);
            h.update(&enc8);
            bcn.bc3.encodeImage(view, &enc16, s);
            h.update(&enc16);
        }
        bcn.bc4.encodeImage(view, &enc8);
        h.update(&enc8);
        bcn.bc5.encodeImage(view, &enc16);
        h.update(&enc16);
    }
    try expectDigest("bc1 to bc5", "62e089d17935fa5ab5f335ab8b619383fcc9f00e0ea2187f4ce174493ec84019", &h);

    var h6 = Sha.init(.{});
    for (0..images.hdr_names.len) |i| {
        const img = images.hdr(i);
        const floats: []const f32 = std.mem.bytesAsSlice(f32, std.mem.sliceAsBytes(&img.pixels));
        const view = bcn.Image(f32).init(floats, W, H, 3);
        for ([_]bcn.bc6h.Format{ .unsigned, .signed }) |f| for ([_]bcn.bc6h.Quality{ .fast, .high }) |q| {
            bcn.bc6h.encodeImageQuality(view, &enc16, f, q);
            h6.update(&enc16);
        };
    }
    try expectDigest("bc6h", "1b1bae2987a276ceb25809a09c922dc322a2f80cf5c9aee0fcaa84e3e5893213", &h6);
}

test "decoders write the recorded bytes, and leave other channels as they were" {
    var h = Sha.init(.{});
    var rng: images.Rng = .{ .state = 0xdec0 };
    var data: [bcn.encodedLen(16, W, H)]u8 = undefined;
    const data8 = data[0..bcn.encodedLen(8, W, H)];
    var out: [images.pixel_count * 4]u8 = undefined;
    var outf: [images.pixel_count * 4]f32 = undefined;
    var outh: [images.pixel_count * 4]u16 = undefined;
    for (0..20) |_| {
        for (&data) |*b| b.* = rng.byte();
        for (1..5) |ch| {
            const c: u8 = @intCast(ch);
            const view: bcn.ImageMut(u8) = .{ .pixels = &out, .width = W, .height = H, .stride = W * c, .channels = c };
            @memset(&out, 0xA5);
            bcn.bc4.decodeImage(data8, view);
            h.update(&out);
            if (c >= 2) {
                @memset(&out, 0xA5);
                bcn.bc5.decodeImage(&data, view);
                h.update(&out);
                @memset(&out, 0xA5);
                bcn.bc5.decodeImageSnorm(&data, view);
                h.update(&out);
            }
        }
        const view4: bcn.ImageMut(u8) = .{ .pixels = &out, .width = W, .height = H, .stride = W * 4, .channels = 4 };
        bcn.bc1.decodeImage(data8, view4);
        h.update(&out);
        bcn.bc3.decodeImage(&data, view4);
        h.update(&out);
        bcn.bc7.decodeImage(&data, view4);
        h.update(&out);
        bcn.bc7.decodeImageF32(&data, .{ .pixels = &outf, .width = W, .height = H, .stride = W * 4, .channels = 4 });
        h.update(std.mem.sliceAsBytes(&outf));
        for ([_]bcn.bc6h.Format{ .unsigned, .signed }) |f| {
            // BC6H writes three of the four channels.
            @memset(&outh, 0xA5A5);
            bcn.bc6h.decodeImage(&data, .{ .pixels = &outh, .width = W, .height = H, .stride = W * 4, .channels = 4 }, f);
            h.update(std.mem.sliceAsBytes(&outh));
        }
    }
    try expectDigest("decoders", "e2d81988765d64e3aada379cbf00addd1e9f9cce006f6ed8ae9c1b2478913ff9", &h);
}
