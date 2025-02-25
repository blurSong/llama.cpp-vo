import sys
import re
import csv


def parse_log_time(lines, timings):
    new_times = timings == []
    for lid in range(len(lines)):
        op, repeat, ms_time = re.match(r"([A-Za-z0-9_\s=]+): (\d+) x ([0-9.]+) ms", lines[lid]).groups()
        if not new_times:
            timings[lid].append(float(ms_time))
        else:
            timings.append([op, int(repeat), float(ms_time)])


def parse_log(logpath, short=False):
    with open(logpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    timings = []
    lidx = 0
    while (lidx < len(lines)):
        # assert only one ubatch for benchmark. repeat n times
        if lines[lidx] == "Vulkan Timings:\n":
            lidx2 = lidx + 2
            while lines[lidx2] != "----------------\n":
                lidx2 += 1
            parse_log_time(lines[lidx+2:lidx2], timings)
            lidx = lidx2
        else:
            lidx += 1

    head = ["Op", "Repeat", "Avg time(ms)", "All times"]
    total_time = 0
    runs = len(timings[0]) - 2
    for tid in range(len(timings)):
        # skip first time for warmup, fiil avg time to it
        avg_time = sum(timings[tid][3:]) / (runs - 1)
        total_time += avg_time * timings[tid][1]
        if short:
            timings[tid] = timings[tid][0:2] + [avg_time]
        else:
            timings[tid][2] = avg_time


    log_timings =  [head] + timings + [["Total time", total_time]]

    timing_csv = logpath.replace(".log", ".csv")
    with open(timing_csv, "w", encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(log_timings)


def clean_log(logpath):
    # the log file may contain mupiple Timing spilits. Combine them and remove the redundant lines
    with open(logpath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for i in range(len(lines)):
        if lines[i] == "Vulkan Timings:\n":
            lines = lines[i:]
            break

    for i in range(len(lines)-1, -1, -1):
        if lines[i] == "----------------\n":
            lines = lines[:i+1]
            break

    i = 0
    while i < len(lines):
        if lines[i] == "----------------\n":
            if i+1 >= len(lines):
                break
            elif lines[i+1] == "Vulkan Timings:\n":
                    if lines[i+2] == "----------------\n":
                        lines[i:i+3] = []
        i += 1

    with open(logpath, 'w', encoding='utf-8') as f:
        for line in lines:
            if line:
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
    clean_log(logpath)
    parse_log(logpath, short=True)

