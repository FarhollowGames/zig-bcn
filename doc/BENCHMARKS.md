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
`d64ab48`, on 23 November 2026. The one-minute load average was 1.0 to 1.3
during the runs.

The figures of v0.3.2, measured on an AMD Ryzen 9 9950X3D at commit
`3ee9b14`, are in this file's history up to commit `73673bf`. That machine
was not available for this pass, so the tables below are from the VM, and
the two machines' figures should not be mixed.

## Results

| feature | zig-bcn Mpix/s | range | original Mpix/s | range | throughput, zig-bcn / original | time, zig-bcn / original | time ratio, range of 3 runs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| bc1 encode normal | 76.55 | 3.0% | 75.27 | 3.0% | 1.02 | 0.98 | 3.2% |
| bc1 encode high | 69.97 | 11.7% | 63.95 | 7.0% | 1.09 | 0.91 | 1.6% |
| bc1 encode normal biased | 75.01 | 2.7% | 72.60 | 3.8% | 1.03 | 0.97 | 0.4% |
| bc3 encode normal | 59.13 | 1.2% | 55.46 | 0.9% | 1.07 | 0.94 | 2.4% |
| bc3 encode high | 55.72 | 10.4% | 49.87 | 5.7% | 1.12 | 0.90 | 1.4% |
| bc4 encode | 356.37 | 5.3% | 243.30 | 5.9% | 1.46 | 0.68 | 1.7% |
| bc5 encode | 175.86 | 5.2% | 120.93 | 4.1% | 1.45 | 0.69 | 0.8% |
| bc7 encode ultrafast | 10.55 | 2.5% | 6.42 | 1.9% | 1.64 | 0.61 | 0.8% |
| bc7 encode veryfast | 2.95 | 1.9% | 1.96 | 3.6% | 1.51 | 0.66 | 5.2% |
| bc7 encode fast | 2.88 | 5.9% | 1.91 | 4.0% | 1.51 | 0.66 | 4.2% |
| bc7 encode basic | 2.06 | 0.2% | 1.29 | 0.5% | 1.60 | 0.63 | 2.7% |
| bc7 encode basic linear | 1.01 | 4.7% | 0.76 | 5.7% | 1.33 | 0.75 | 1.0% |
| bc7 encode slow | 1.63 | 5.7% | 0.99 | 0.6% | 1.65 | 0.61 | 2.8% |
| bc7 encode veryslow | 0.46 | 15.9% | 0.24 | 7.6% | 1.92 | 0.52 | 0.2% |
| bc7 encode slowest | 0.36 | 4.5% | 0.18 | 1.9% | 2.00 | 0.50 | 2.7% |
| bc6h encode unsigned | 2.51 | 2.2% | 1.96 | 1.9% | 1.28 | 0.78 | 2.4% |
| bc6h encode signed | 1.82 | 7.7% | 1.56 | 7.4% | 1.17 | 0.86 | 2.8% |
| bc6h encode unsigned, texcomp simd | 2.52 | 3.8% | 2.05 | 0.7% | 1.23 | 0.81 | 1.2% |
| bc6h encode signed, texcomp simd | 1.80 | 3.9% | 1.63 | 10.8% | 1.10 | 0.91 | 1.6% |
| bc6h encode high unsigned | 0.39 | 2.6% | no original | | | | |
| bc6h encode high signed | 0.36 | 11.8% | no original | | | | |
| bc1 decode | 1171.55 | 2.6% | 857.09 | 6.6% | 1.37 | 0.73 | 2.2% |
| bc3 decode | 829.34 | 4.8% | 596.95 | 3.7% | 1.39 | 0.72 | 0.9% |
| bc4 decode | 4932.33 | 2.1% | 2594.21 | 2.2% | 1.90 | 0.53 | 1.2% |
| bc5 decode | 882.25 | 3.8% | 814.66 | 4.2% | 1.08 | 0.92 | 2.1% |
| bc5 decode snorm | 767.14 | 3.4% | 354.19 | 3.3% | 2.17 | 0.46 | 1.2% |
| bc7 decode | 297.94 | 29.9% | 180.24 | 20.3% | 1.65 | 0.60 | 1.6% |
| bc7 decode f32 | 292.06 | 0.9% | 159.62 | 0.6% | 1.83 | 0.55 | 1.7% |
| bc6h decode unsigned | 347.86 | 9.1% | 229.76 | 6.4% | 1.51 | 0.66 | 0.8% |
| bc6h decode signed | 285.10 | 0.9% | 142.74 | 3.2% | 2.00 | 0.50 | 1.8% |

## BC7 speed pass: before and after

Both binaries built the same way on the same machine: v0.3.2 (commit
`73673bf`) and this pass (commit `d64ab48`), with the same originals. The
before and after runs alternated, three of each with `--rounds 3`; each row
is from the run with the median time ratio. The original's throughput is
from the after runs; it moved by under 5% between them.

| feature | before, zig-bcn Mpix/s | after, zig-bcn Mpix/s | original Mpix/s | time ratio before | time ratio after |
| --- | ---: | ---: | ---: | ---: | ---: |
| bc1 encode normal | 78.34 | 76.55 | 75.27 | 0.97 | 0.98 |
| bc1 encode high | 67.93 | 69.97 | 63.95 | 0.92 | 0.91 |
| bc1 encode normal biased | 75.35 | 75.01 | 72.60 | 0.97 | 0.97 |
| bc3 encode normal | 59.97 | 59.13 | 55.46 | 0.93 | 0.94 |
| bc3 encode high | 54.75 | 55.72 | 49.87 | 0.91 | 0.90 |
| bc4 encode | 355.52 | 356.37 | 243.30 | 0.68 | 0.68 |
| bc5 encode | 180.03 | 175.86 | 120.93 | 0.69 | 0.69 |
| bc7 encode ultrafast | 5.39 | 10.55 | 6.42 | 1.19 | 0.61 |
| bc7 encode veryfast | 1.59 | 2.95 | 1.96 | 1.22 | 0.66 |
| bc7 encode fast | 1.57 | 2.88 | 1.91 | 1.22 | 0.66 |
| bc7 encode basic | 1.06 | 2.06 | 1.29 | 1.25 | 0.63 |
| bc7 encode basic linear | 0.59 | 1.01 | 0.76 | 1.31 | 0.75 |
| bc7 encode slow | 0.79 | 1.63 | 0.99 | 1.22 | 0.61 |
| bc7 encode veryslow | 0.21 | 0.46 | 0.24 | 1.14 | 0.52 |
| bc7 encode slowest | 0.16 | 0.36 | 0.18 | 1.19 | 0.50 |
| bc6h encode unsigned | 2.55 | 2.51 | 1.96 | 0.79 | 0.78 |
| bc6h encode signed | 1.81 | 1.82 | 1.56 | 0.85 | 0.86 |
| bc6h encode unsigned, texcomp simd | 2.56 | 2.52 | 2.05 | 0.82 | 0.81 |
| bc6h encode signed, texcomp simd | 1.79 | 1.80 | 1.63 | 0.90 | 0.91 |
| bc6h encode high unsigned | 0.40 | 0.39 | no original | | |
| bc6h encode high signed | 0.36 | 0.36 | no original | | |
| bc1 decode | 1120.23 | 1171.55 | 857.09 | 0.78 | 0.73 |
| bc3 decode | 760.83 | 829.34 | 596.95 | 0.83 | 0.72 |
| bc4 decode | 3488.67 | 4932.33 | 2594.21 | 0.72 | 0.53 |
| bc5 decode | 612.14 | 882.25 | 814.66 | 1.30 | 0.92 |
| bc5 decode snorm | 293.65 | 767.14 | 354.19 | 1.21 | 0.46 |
| bc7 decode | 296.60 | 297.94 | 180.24 | 0.61 | 0.60 |
| bc7 decode f32 | 303.74 | 292.06 | 159.62 | 0.54 | 0.55 |
| bc6h decode unsigned | 332.31 | 347.86 | 229.76 | 0.66 | 0.66 |
| bc6h decode signed | 289.85 | 285.10 | 142.74 | 0.55 | 0.50 |

Rows this pass did not touch moved by up to about a tenth between the
before and after runs, which is this VM's noise between runs. BC3 decode
did change: its alpha is a BC4 block.

## Notes and known biases

- **BC7 encoding** is faster than bc7e's scalar C++ build, the one
  vendored here, at every level on this machine, time ratio 0.50 to 0.75.
  Before this pass it was 1.14 to 1.31 here. The per-pixel loops run on
  vectors of the block's 16 pixels: the palette evaluation, the partition
  estimate (every subset of a partition in one pass) and the mode 4 and 5
  alpha search. Each lane does the original's float steps in its order,
  and the sums across pixels stay scalar and in pixel order, so the bytes
  are the same; unit tests compare each vector loop with the scalar loop
  it replaced.
- **bc7e's ISPC build is faster than zig-bcn** at every level: zig-bcn
  takes 1.06 to 1.61 times as long as it with bc7e's own build flags, and
  1.67 to 2.39 times as long as an AVX-512 build of it (see "BC7 against
  bc7e's ISPC build" below). The ISPC build runs the search on several
  blocks at once, one block to a lane, so every step of the search is on
  vectors, including the parts that are scalar in zig-bcn. zig-bcn keeps
  one block at a time and the scalar C++ build's exact float steps, which
  is what lets it be checked byte for byte.
- **What is not faster.** The rest of the BC7 search is still the scalar
  translation: the principal-axis fit, the least squares refinement and the
  endpoint quantization, whose sums over pixels must keep their order. In a
  profile of `basic` these take as long as bc7e's counterparts or longer,
  up to about twice as long for the endpoint quantization; inlining differs
  between the two builds, so the per-function figures are rough.
  `basic linear` gains least (0.76): its mode 6 search tries only two
  palette entries per pixel, where the perceptual search tries every
  entry, so there is less per-pixel work for the vectors to take over. No
  row of `zig build bench` is slower than its original on this machine.
- **BC7 with bc7e's default float flags.** With clang's default `-ffp-
  contract=on`, which fuses multiply-adds and changes bc7e's bytes
  (measured by adding `"-ffp-contract=on"` after `"-O3"` in `addBench` in
  `build.zig`), bc7e's BC7 rows moved by 5% or less, some up and some
  down, and zig-bcn stayed 1.34 to 1.91 times as fast. This was one run of
  `--rounds 3`, at `94cc7c0`, before a refactor of the palette code that
  does not change its work.
- **BC5 decoding** was slower than texcomp's on this machine before this
  pass (time ratio 1.30, SNORM 1.21), though not on the Ryzen. Each
  pixel's two bytes went through a `[16][2]u8` array that LLVM assembled
  byte by byte in general registers. Whole blocks are now stored from the
  lanes, and the BC4 palette divides in 16-bit lanes; the ratios are 0.92
  and 0.46. BC5 decode remains the closest decoder row: texcomp writes all
  four bytes of a pixel at once, and zig-bcn writes only red and green,
  two bytes at a time, so that it never touches blue and alpha.
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

## BC7 against bc7e's ISPC build

bc7e's fast build is `bc7e.ispc`, compiled with Intel's ISPC; the scalar
C++ above is basis_universal's translation of it. This comparison is not
part of the default `zig build bench`. The ISPC source is
[richgel999/bc7enc_rdo](https://github.com/richgel999/bc7enc_rdo) at
commit `b943862`, compiled with ISPC 1.25.3 and the flags of that
repository's `CMakeLists.txt`:

```sh
# in a directory outside this repository, with bc7e.ispc in it
ispc -O2 bc7e.ispc -o bc7e.o -h bc7e_ispc.h --target=sse2,sse4,avx,avx2 \
    --opt=fast-math --opt=disable-assertions --pic
# back in this repository; $ISPC_OUT is that directory
zig build bench -Dbc7e-ispc=$ISPC_OUT/bc7e.o -Dbc7e-ispc=$ISPC_OUT/bc7e_sse2.o \
    -Dbc7e-ispc=$ISPC_OUT/bc7e_sse4.o -Dbc7e-ispc=$ISPC_OUT/bc7e_avx.o \
    -Dbc7e-ispc=$ISPC_OUT/bc7e_avx2.o -- --filter ispc --rounds 3
```

These rows print "bytes not compared": the ISPC build is not an oracle.

ISPC picks its AVX2 code at run time on this machine. The last two columns
are one run of a build with `--target=avx512skx-x16` instead, which bc7e's
own build does not use. The ISPC build takes its parameters from its own
`bc7e_compress_block_params_init_*` functions; they are the port's, except
that it has no `use_luts` switch and always uses the tables.

| feature | zig-bcn Mpix/s | bc7e ISPC Mpix/s | time ratio | time ratio, range of 3 runs | bc7e ISPC AVX-512 Mpix/s | time ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| bc7 encode ultrafast | 10.53 | 13.43 | 1.28 | 1.0% | 17.37 | 1.65 |
| bc7 encode veryfast | 2.89 | 4.64 | 1.61 | 1.4% | 6.73 | 2.34 |
| bc7 encode fast | 2.87 | 4.60 | 1.60 | 2.9% | 6.70 | 2.33 |
| bc7 encode basic | 2.06 | 3.10 | 1.50 | 1.0% | 4.34 | 2.11 |
| bc7 encode basic linear | 1.00 | 1.42 | 1.42 | 1.1% | 1.93 | 1.91 |
| bc7 encode slow | 1.55 | 2.20 | 1.42 | 1.4% | 3.73 | 2.39 |
| bc7 encode veryslow | 0.46 | 0.53 | 1.15 | 2.2% | 0.85 | 1.89 |
| bc7 encode slowest | 0.36 | 0.38 | 1.06 | 2.7% | 0.60 | 1.67 |

Time ratio is zig-bcn's time over the ISPC build's: above 1, zig-bcn is
slower. Same machine, method and image set as above, three runs of
`--rounds 3` for the AVX2 columns, at commit `031d30f`, whose encoder code
is that of `5862a52`.

The bytes differ, since the ISPC build uses fast math, but it does the
same search: on the image set, at `ultrafast`, `basic` and `slowest`, both
metrics, 86% to 95% of the blocks are identical. The two encoders' RGBA
PSNR is equal to within 0.001 dB, at 19 to 21 dB: the image set is made to
be hard (noise, hue stripes, extremes), so this says they do the same
work, not how good either is on real textures.

The gap is smallest at `veryslow` and `slowest` and largest at `veryfast`
to `slow`; the cause was not profiled. Against bc7e's scalar C++ build, measured above, the
ISPC build is 2.1 to 2.4 times as fast here; the scalar build is compiled
for this CPU at `-O3`, so clang vectorizes some of its loops too.

## Other CPU targets

The tables above are for `-Dtarget=native`. The same pass built for other
x86-64 levels, BC7 rows only, one run of `--rounds 3` each, both sides built
for the same CPU (time ratio, zig-bcn / bc7e's scalar build):

| feature | `x86_64_v3` (AVX2) | baseline (SSE2) |
| --- | ---: | ---: |
| bc7 encode ultrafast | 0.53 | 0.58 |
| bc7 encode veryfast | 0.57 | 0.63 |
| bc7 encode fast | 0.57 | 0.63 |
| bc7 encode basic | 0.54 | 0.61 |
| bc7 encode basic linear | 0.66 | 0.19 |
| bc7 encode slow | 0.53 | 0.62 |
| bc7 encode veryslow | 0.44 | 0.57 |
| bc7 encode slowest | 0.44 | 0.57 |

Baseline is what a cross-compiled x86-64 build gets without `-Dcpu`. It
has no vector floor instruction (that came with SSE4.1), so the lane
floor goes through integers there, which is exact for the values it sees.
zig-bcn has no run-time CPU dispatch: a baseline build runs the SSE2 code
on any CPU. On this machine the AVX2 build is faster than the AVX-512 one,
so `-Dcpu=x86_64_v3` is the build to use for tools on recent x86-64 CPUs.
On SSE2, bc7e's `basic linear` runs at about a fifth of its AVX2 speed,
which makes that row's ratio small; the cause was not investigated.

## Build modes

`zig build bench` runs ReleaseFast. The asset tools may be built in other
modes, so BC7 encoding of the image set (all 7 levels, both metrics, RGBA
and RGB sources, and 3,000 random blocks) was also timed in each mode,
against v0.3.2 built the same way: time of this pass over v0.3.2's, median
of 3 runs, range over the rows.

| build | time, this pass / v0.3.2 |
| --- | ---: |
| ReleaseFast, native | 0.48 to 0.73 |
| ReleaseFast, `x86_64_v3` | 0.41 to 0.65 |
| ReleaseFast, baseline | 0.29 to 0.54 |
| ReleaseSafe, native | 0.48 to 0.67 |
| ReleaseSafe, baseline | 0.52 to 0.80 |
| Debug, LLVM (`-fllvm`, or `.use_llvm = true`) | 0.34 to 0.54 |
| Debug, Zig's x86-64 backend | 1.16 to 1.81 |

Debug builds for x86_64-linux use Zig's own x86-64 backend by default,
which compiles the lane code poorly: BC7 encoding there is **slower** than
in v0.3.2. Debug on Windows uses LLVM. A Debug tool that encodes textures
on Linux should be built with LLVM, or the tool with ReleaseSafe. The
Debug rows leave out `veryslow` and `slowest`.

## Threads

Encoding in bands of block rows scales with the cores: BC7 `basic` on a
1024 x 1024 image took 1.05 s on one thread and 62 ms on 32, at v0.3.2 on
the Ryzen, before this pass. This figure does not come from `zig build
bench`, which runs on one thread.
