# chpl-perf-tools

## Overview

`perf` is a linux tool that can be used to profile applications. This repository contains a few scripts that can be used to profile Chapel programs using `perf`.

The two most common uses of `perf` are to collect event counts or to identify hotspots in the code. `perf stat` is used to collect event counts, while `perf record` is used to identify hotspots. `perf stat` is generally invoked with a set of events to count, which is then aggregated over the run of the application and written to a file. `perf record` is used to record the performance of the application, and then `perf report` is used to analyze the results.

For more information, <https://perfwiki.github.io/main/> is a great resource.

## `perf` usage

`perf` is typically used from the command line as

```bash
perf record -o perf.data ./my_program
```

This works well for single-locale Chapel programs that do not use a launcher. The scripts in this repository are designed to work with Chapel programs that use a launcher and can also be used with multi-locale programs.

The basic usage is:

```bash
export CHPL_LAUNCHER_REAL_WRAPPER=/path/to/perf_wrapper.sh
export CHPL_PERF_CMD=stat # optional, default is 'record'
export CHPL_PERF_ARGS="-e cycles,instructions" # optional, if extra perf args are needed
export CHPL_PERF_BASE_NAME=run1 # optional
./my_chpl_program
```

For a single-locale program, this will result in a single file, `perf.data.run1.$(hostname)`, which contains the number of cycles and instructions executed by the program. For a multi-locale program, there will be a file for each locale, distinguished by the locale's hostname. This does not work with co-locales!!

## Finer control

Just using `perf_wrapper.sh` as described above will result in profiling the entire program. If you want to profile only a specific part of the program, you can include the `PerfControl` module in your program and use the `enablePerfCounters` and `disablePerfCounters` functions to start and stop profiling. Then, when running the program, set `export CHPL_PERF_USE_CTL=1` to only start profiling when `enablePerfCounters` is called.

```bash
# same env variables as above
# ...
export CHPL_PERF_USE_CTL=1
./my_chpl_program
```

If you are running a multi-locale program, you can selectively enable `perf` on each locale by calling `enablePerfCounters`, with a locale argument, for example `enablePerfCounters(Locales[1])` to enable `perf` on locale 1. A shortcut for enabling `perf` on all locales is `enableAllPerfCounters`. The same is true for `disablePerfCounters`.

For example,

```chapel

use PerfControl;

//
// Some initialization code we don't want to profile
//

...

enableAllPerfCounters();

//
// Computation we want to profile
//

...


//
// Disable profiling before doing teardown
//

disableAllPerfCounters();

...

```

## `perf report`

After running `perf record`, use `perf report -i perf.data.filename` to analyze the results. This will show which functions in the program are taking the most time, and then you can drill down to see which lines in the function are the hotspots. When using this in Chapel, it can be difficult to map the function names reported in `perf` back to the Chapel source code without reading the generated code (especially generic code), so it is recommended to compile with the `--savec gen_code` flag.

## Best Practices

For best results when using `perf record`, it is recommended to compile your code with the following flags:

- `-g --no-cpp-lines` - includes debugging information in the binary, this makes it easier to map the hotspots back to the source code, but may slightly pmed optimizations
- `--savec gen_code` - save the generated code to a directory, this helps `perf report` understand the debug information

If you have having issues understanding the `perf` output with the default LLVM backend, you can try using the C backend. It is easier to inspect the generated C code and manually map it back to the Chapel source code.
