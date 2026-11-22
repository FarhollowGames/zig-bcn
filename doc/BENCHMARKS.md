# Benchmarks

These are measurements on one machine, under the conditions below. They
are not a verdict on either side.

## Method

`zig build bench` times every encoder against its original and every
decoder against texcomp's, on one thread, on every block of the test image
set (2,688 RGBA and 1,536 HDR blocks, see [`TESTING.md`](TESTING.md)), and
checks that both sides write the same bytes. The BC6H `simd` rows run
texcomp with its AVX2 selector kernels, the other BC6H rows with its scalar
search.

- **zig-bcn**: ReleaseFast, for the CPU it runs on.
- **The originals**: Zig's clang at `-O3`, for the same CPU, C as
  `-std=c11` and C++ as `-std=c++17 -fno-exceptions -fno-rtti
  -fno-threadsafe-statics`, with the flags their exact output needs:
  `-ffp-contract=off -fno-fast-math`, and `-fwrapv` for the C.
- **Samples**: each lasts at least 25 ms of the benchmark thread's CPU
  time, after two warm-ups, and the two sides' samples alternate. Every
  pass's output is kept behind a compiler barrier, so no pass can be
  removed, and the two sides' outputs are compared.
- **Reported**: the median of 11 samples in megapixels a second, the best
  median of three rounds for each side; range is (slowest - fastest) /
  median. The time ratio is the original's throughput divided by zig-bcn's:
  below 1, zig-bcn takes less time.
- **Three runs**: the command below ran three times. Each row is from the
  run with the median time ratio, and the last column is the range of the
  three runs' time ratios, (largest - smallest) / median.

```sh
zig build bench -- --rounds 3
zig build bench -- --filter decode --rounds 3   # one group of rows
```

## Machine

An Intel Xeon cloud VM (Granite Rapids; Zig's CPU name `graniterapids`,
AVX-512), 4 virtual CPUs under KVM, Linux 6.18, Zig 0.17.0, at commit
`94cc7c0`, on 22 November 2026. The one-minute load average was 0.6 to 1.0
during the runs.

The figures of v0.3.2, measured on an AMD Ryzen 9 9950X3D at commit
`3ee9b14`, are in this file's history up to commit `73673bf`. That machine
was not available for this pass, so the tables below are from the VM, and
the two machines' figures should not be mixed.

## Results

| feature | zig-bcn Mpix/s | range | original Mpix/s | range | throughput, zig-bcn / original | time, zig-bcn / original | time ratio, range of 3 runs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| bc1 encode normal | 75.58 | 2.4% | 73.58 | 1.3% | 1.03 | 0.97 | 1.6% |
| bc1 encode high | 68.17 | 3.7% | 63.31 | 2.7% | 1.08 | 0.93 | 1.8% |
| bc1 encode normal biased | 74.21 | 2.4% | 71.98 | 3.8% | 1.03 | 0.97 | 3.3% |
| bc3 encode normal | 58.91 | 2.6% | 55.53 | 25.4% | 1.06 | 0.94 | 0.7% |
| bc3 encode high | 54.33 | 2.1% | 48.76 | 0.9% | 1.11 | 0.90 | 1.0% |
| bc4 encode | 362.02 | 5.5% | 244.78 | 4.5% | 1.48 | 0.68 | 0.7% |
| bc5 encode | 173.48 | 3.9% | 117.85 | 3.2% | 1.47 | 0.68 | 0.7% |
| bc7 encode ultrafast | 10.57 | 2.4% | 6.44 | 3.2% | 1.64 | 0.61 | 3.2% |
| bc7 encode veryfast | 2.89 | 20.5% | 1.91 | 1.0% | 1.51 | 0.66 | 2.1% |
| bc7 encode fast | 2.88 | 4.0% | 1.91 | 1.0% | 1.51 | 0.66 | 1.9% |
| bc7 encode basic | 2.07 | 10.7% | 1.29 | 0.7% | 1.60 | 0.62 | 2.0% |
| bc7 encode basic linear | 1.01 | 4.0% | 0.77 | 3.1% | 1.31 | 0.76 | 2.0% |
| bc7 encode slow | 1.56 | 17.5% | 0.95 | 13.8% | 1.64 | 0.61 | 1.9% |
| bc7 encode veryslow | 0.46 | 2.5% | 0.24 | 3.6% | 1.92 | 0.52 | 4.1% |
| bc7 encode slowest | 0.36 | 0.5% | 0.19 | 13.7% | 1.89 | 0.53 | 0.0% |
| bc6h encode unsigned | 2.52 | 3.6% | 1.98 | 1.2% | 1.27 | 0.79 | 1.3% |
| bc6h encode signed | 1.79 | 14.9% | 1.52 | 1.7% | 1.18 | 0.85 | 1.3% |
| bc6h encode unsigned, texcomp simd | 2.53 | 6.3% | 2.07 | 1.5% | 1.22 | 0.82 | 0.3% |
| bc6h encode signed, texcomp simd | 1.80 | 2.9% | 1.63 | 1.5% | 1.10 | 0.91 | 1.8% |
| bc6h encode high unsigned | 0.39 | 2.8% | no original | | | | |
| bc6h encode high signed | 0.36 | 0.6% | no original | | | | |
| bc1 decode | 1125.37 | 1.0% | 852.87 | 3.0% | 1.32 | 0.76 | 4.1% |
| bc3 decode | 818.98 | 2.8% | 619.19 | 2.8% | 1.32 | 0.76 | 1.0% |
| bc4 decode | 4794.59 | 2.4% | 2526.32 | 2.5% | 1.90 | 0.53 | 0.1% |
| bc5 decode | 843.35 | 0.4% | 796.34 | 1.7% | 1.06 | 0.94 | 0.5% |
| bc5 decode snorm | 752.79 | 0.4% | 354.49 | 0.5% | 2.12 | 0.47 | 0.4% |
| bc7 decode | 296.29 | 1.7% | 180.30 | 1.0% | 1.64 | 0.61 | 0.7% |
| bc7 decode f32 | 302.74 | 7.5% | 167.77 | 3.8% | 1.80 | 0.55 | 2.0% |
| bc6h decode unsigned | 332.60 | 2.0% | 222.17 | 1.5% | 1.50 | 0.67 | 0.6% |
| bc6h decode signed | 284.27 | 0.6% | 139.31 | 6.1% | 2.04 | 0.49 | 1.6% |

## BC7 speed pass: before and after

Both binaries built the same way on the same machine: v0.3.2 (commit
`73673bf`) and this pass (commit `94cc7c0`), with the same originals. The
before and after runs alternated, three of each with `--rounds 3`; each row
is from the run with the median time ratio. The original's throughput is
from the after runs; it moved by under 5% between them.

| feature | before, zig-bcn Mpix/s | after, zig-bcn Mpix/s | original Mpix/s | time ratio before | time ratio after |
| --- | ---: | ---: | ---: | ---: | ---: |
| bc1 encode normal | 75.99 | 75.58 | 73.58 | 0.97 | 0.97 |
| bc1 encode high | 67.60 | 68.17 | 63.31 | 0.92 | 0.93 |
| bc1 encode normal biased | 75.00 | 74.21 | 71.98 | 0.97 | 0.97 |
| bc3 encode normal | 59.54 | 58.91 | 55.53 | 0.94 | 0.94 |
| bc3 encode high | 54.55 | 54.33 | 48.76 | 0.89 | 0.90 |
| bc4 encode | 355.67 | 362.02 | 244.78 | 0.68 | 0.68 |
| bc5 encode | 171.64 | 173.48 | 117.85 | 0.68 | 0.68 |
| bc7 encode ultrafast | 5.41 | 10.57 | 6.44 | 1.19 | 0.61 |
| bc7 encode veryfast | 1.56 | 2.89 | 1.91 | 1.22 | 0.66 |
| bc7 encode fast | 1.57 | 2.88 | 1.91 | 1.22 | 0.66 |
| bc7 encode basic | 1.04 | 2.07 | 1.29 | 1.25 | 0.62 |
| bc7 encode basic linear | 0.58 | 1.01 | 0.77 | 1.31 | 0.76 |
| bc7 encode slow | 0.78 | 1.56 | 0.95 | 1.22 | 0.61 |
| bc7 encode veryslow | 0.21 | 0.46 | 0.24 | 1.14 | 0.52 |
| bc7 encode slowest | 0.16 | 0.36 | 0.19 | 1.19 | 0.53 |
| bc6h encode unsigned | 2.52 | 2.52 | 1.98 | 0.79 | 0.79 |
| bc6h encode signed | 1.79 | 1.79 | 1.52 | 0.85 | 0.85 |
| bc6h encode unsigned, texcomp simd | 2.51 | 2.53 | 2.07 | 0.82 | 0.82 |
| bc6h encode signed, texcomp simd | 1.80 | 1.80 | 1.63 | 0.89 | 0.91 |
| bc6h encode high unsigned | 0.39 | 0.39 | no original | | |
| bc6h encode high signed | 0.36 | 0.36 | no original | | |
| bc1 decode | 1122.72 | 1125.37 | 852.87 | 0.78 | 0.76 |
| bc3 decode | 725.57 | 818.98 | 619.19 | 0.85 | 0.76 |
| bc4 decode | 3512.61 | 4794.59 | 2526.32 | 0.72 | 0.53 |
| bc5 decode | 611.72 | 843.35 | 796.34 | 1.30 | 0.94 |
| bc5 decode snorm | 293.27 | 752.79 | 354.49 | 1.21 | 0.47 |
| bc7 decode | 296.06 | 296.29 | 180.30 | 0.61 | 0.61 |
| bc7 decode f32 | 294.95 | 302.74 | 167.77 | 0.55 | 0.55 |
| bc6h decode unsigned | 336.72 | 332.60 | 222.17 | 0.65 | 0.67 |
| bc6h decode signed | 283.77 | 284.27 | 139.31 | 0.55 | 0.49 |

Rows that this pass did not touch moved within the runs' noise. BC3 decode
also changed: its alpha is a BC4 block.

## Notes and known biases

- **BC7 encoding** is faster than bc7e at every level on this machine,
  time ratio 0.52 to 0.76. Before this pass it was 1.14 to 1.31 here. The
  per-pixel loops run on vectors of the block's 16 pixels: the palette
  evaluation, the partition estimate (every subset of a partition in one
  pass) and the mode 4 and 5 alpha search. Each lane does the original's
  float steps in its order, and the sums across pixels stay scalar and in
  pixel order, so the bytes are the same; unit tests compare each vector
  loop with the scalar loop it replaced.
- **Still slower, or no faster.** The rest of the BC7 search is the scalar
  translation and runs at about bc7e's speed: the principal-axis fit, the
  least squares refinement and the endpoint quantization, whose sums over
  pixels must keep their order. `basic linear` gains least (0.76): its
  mode 6 search tries only two palette entries per pixel, where the
  perceptual search tries every entry, so there is less per-pixel work for
  the vectors to take over. No row of `zig build
  bench` is slower than its original on this machine.
- **BC7 with bc7e's default float flags.** With clang's default
  `-ffp-contract=on`, which fuses multiply-adds and changes bc7e's bytes,
  bc7e's BC7 rows moved by 5% or less, some up and some down; zig-bcn
  stayed 1.34 to 1.91 times as fast.
- **BC5 decoding** was slower than texcomp's on this machine before this
  pass (time ratio 1.30, SNORM 1.21), though not on the Ryzen. Each
  pixel's two bytes went through a `[16][2]u8` array that LLVM assembled
  byte by byte in general registers. Whole blocks are now stored a row at
  a time from the lanes, and the BC4 palette divides in 16-bit lanes; the
  ratios are 0.94 and 0.47. BC5 decode remains the closest decoder row:
  texcomp writes all four bytes of a pixel at once, and zig-bcn reads and
  writes back blue and alpha to leave them as they were.
- **BC5 encoding** measured 0.98 of stb_dxt's throughput on the Ryzen; on
  this machine it measures 1.47, the same as BC4, so the Ryzen figure
  looks like that machine's, not the code's. It was not re-measured there.
- **BC6H** runs its selector search and partition boxes on vectors of the
  block's 16 texels, with the same integer arithmetic as texcomp's SIMD
  kernels. texcomp's own AVX2 kernels make no difference here: built for
  this CPU, its scalar search is vectorized by the compiler too.
- **The decoders** decode a block's 16 pixels at once, in vector lanes.
  The comparisons are not of identical work in two cases. texcomp's BC5
  decoders write blue and alpha as well; zig-bcn's write red and green
  only. texcomp's BC7 float decoder decodes the image to bytes in a buffer
  it allocates for each call, then converts them; zig-bcn converts each
  block's lanes. zig-bcn's SNORM decoder turns signed values into bytes
  with integer lanes, which give exactly texcomp's float steps.
- **CPU time, not wall time.** This leaves out the time other processes
  hold the core; memory and cache contention from them still reach both
  sides.
- **The exactness flags** cost the originals little: built with fused
  multiply-add and without `-fwrapv`, they write different bytes, and only
  BC1 gets measurably faster (about a tenth). The rows above use the exact
  build, since only then do both sides do the same work.
- **`bc6h encode high`** has no original. [`bc6h-quality.md`](bc6h-quality.md)
  compares its quality and speed with texcomp and with Microsoft's
  DirectXTex on HDR photographs and the test images, on the same machine.

## Threads

Encoding in bands of block rows scales with the cores: BC7 `basic` on a
1024 x 1024 image took 1.05 s on one thread and 62 ms on 32, at v0.3.2 on
the Ryzen, before this pass. This figure does not come from `zig build
bench`, which runs on one thread.
