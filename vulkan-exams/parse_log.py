# A typical log file timing looks like: (w/--process)
"""
submit counts 741
Vulkan Timings:
----------------
ADD: 64 x 0.235422 ms
CONT: 32 x 0.176125 ms
CPY: 64 x 0.137859 ms
GET_ROWS: 2 x 0.0485 ms
MUL: 97 x 0.264103 ms
MUL_MAT m=1024 n=128 k=4096: 64 x 0.58075 ms
MUL_MAT m=128 n=128 k=128: 64 x 0.247641 ms
MUL_MAT m=14336 n=128 k=4096: 62 x 4.10923 ms
MUL_MAT m=4096 n=128 k=14336: 31 x 4.14526 ms
MUL_MAT m=4096 n=128 k=4096: 64 x 1.47473 ms
MUL_MAT_VEC m=128256 k=4096: 1 x 5.072 ms
MUL_MAT_VEC m=14336 k=4096: 2 x 0.494 ms
MUL_MAT_VEC m=4096 k=14336: 1 x 0.638 ms
RMS_NORM: 65 x 0.203662 ms
ROPE: 64 x 0.186953 ms
SILU: 32 x 0.319312 ms
SOFT_MAX: 32 x 0.189781 ms
----------------
llama-bench: benchmark 1/1: generation run 1/10
"""


import sys
import re
import csv


def parse_log_time(lines, timings):
    new_times = timings == []
    for lid in range(len(lines)):
        op, repeat, ms_time = re.match(r"([A-Za-z0-9_\s=]+): (\d+) x ([0-9.]+) ms", lines[lid]).groups()
        if not new_times:
            assert timings[lid][0] == op, f"op {timings[lid][0]} != {op}"
            timings[lid].append(float(ms_time))
        else:
            timings.append([op, int(repeat), float(ms_time)])


def parse_log(logpath, short=False):
    with open(logpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    submit_count = int(lines[0].split(" ")[-1])

    prompt_timings = []
    generation_timings = []

    uidx = 1
    lidx = 1
    while (lidx < len(lines)):
        if lines[lidx].startswith("llama-bench"):
            if "warmup" not in lines[lidx]:
                if "prompt" in lines[lidx]:
                    parse_log_time(lines[uidx:lidx], prompt_timings)
                elif "generation" in lines[lidx]:
                    parse_log_time(lines[uidx:lidx], generation_timings)
                else:
                    raise ValueError("unkown: " + lines[lidx])
            uidx = lidx + 1
        lidx += 1

    head = ["op", "repeat", "avg time (ms)", "all times"]
    for timings in [prompt_timings, generation_timings]:
        total_time = 0
        runs = len(timings[0]) - 2
        for tid in range(len(timings)):
            avg_time = sum(timings[tid][2:]) / runs
            total_time += avg_time * timings[tid][1]
            if short:
                timings[tid] = timings[tid][:2] + [avg_time]
            else:
                timings[tid][2] = avg_time

        if timings == prompt_timings:
            timings.append(["Prompt time", total_time])
        else:
            timings.append(["Generation time", total_time])


    log_timings =  [head] + prompt_timings + generation_timings

    timing_csv = logpath.replace(".log", ".csv")
    with open(timing_csv, "w", encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(log_timings)


def cleanup_log(logpath):
    # the log file may contain mupiple Timing spilits. Combine them and remove the redundant lines
    with open(logpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    submit_counts = 0
    # eliminate tail and head

    for i in range(len(lines)):
        if lines[i].startswith("submit counts"):
            submit_counts = int(lines[i].split(" ")[-1])
            lines = lines[i:]
            break

    for i in range(len(lines)-1, -1, -1):
        if lines[i].startswith("-----"):
            lines = lines[:i+1]
            break

    with open(logpath, 'w', encoding='utf-8') as f:
        f.write(f"submit counts {submit_counts}\n")
        for line in lines:
            if line.startswith("submit counts") or line.startswith("Vulkan Timings") or line.startswith("-----"):
                continue
            f.write(line)


def parse_gemm_log(logpath):
    # GEMM Log is like
    # TEST F16_F32_ALIGNED_L m=4096 n=128 k=4096 batch=1 split_k=1 matmul 2.30262ms 1.86525 TFLOPS avg_err=4.04995e-05
    with open(logpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    test_lines = []
    for line in lines:
        if line.startswith("TEST"):
            test_lines.append(line.strip('\n'))

    head = ["OP", "m", "n", "k", "batch", "split_k", "time ms", "tflops"]
    logrows = [head]
    for line in test_lines:
        line = line.split(" ")
        if line[1] == "MMQ":
            line.remove("MMQ")

        op = line[1]
        m = int(line[2].split('=')[1])
        n = int(line[3].split('=')[1])
        k = int(line[4].split('=')[1])
        batch = int(line[5].split('=')[1])
        split_k = int(line[6].split('=')[1])
        time = float(line[8].rstrip('ms'))
        tflops = float(line[9])
        logrows.append([op, m, n, k, batch, split_k, time, tflops])

    log_csv = logpath.replace(".log", ".csv")
    with open(log_csv, "w", encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(logrows)


if __name__ == "__main__":
    logpath = sys.argv[1]

if "gemm" in logpath: # gemm log
    parse_gemm_log(logpath)
else: # e2e log
    cleanup_log(logpath)
    parse_log(logpath, short=True)

