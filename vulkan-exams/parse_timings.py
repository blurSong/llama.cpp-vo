import sys
import re
import csv


def parse_time(lines, timings):
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
            parse_time(lines[lidx+2:lidx2], timings)
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


if __name__ == "__main__":
    logpath = sys.argv[1]
    if len(sys.argv) > 2:
        short = sys.argv[2] == "short"
    else:
        short = False
    clean_log(logpath)
    parse_log(logpath, short)

