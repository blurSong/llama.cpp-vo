import sys
import re
import csv


def parse_time(lines, timings):
    lines.remove("\n")
    new_times = timings == []
    for lid in range(len(lines)):
        op, repeat, ms_time = re.match(r"([A-Za-z0-9_\s=]+): (\d+) x ([0-9.]+) ms", lines[lid]).groups()
        if not new_times:
            timings[lid].append(float(ms_time))
        else:
            timings.append([op, int(repeat), float(ms_time)])


def parse_log(logpath):
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
            parse_time(lines[lidx+2:lidx2-1], timings)
            lidx = lidx2
        else:
            lidx += 1

    head = ["Op", "Repeat", "Avg time(ms)", "Times"]
    total_time = 0
    for i in range(len(timings)):
        # skip first time for warmup, fiil avg time to it
        avg_time = sum(timings[i][3:]) / len(timings[i][3:])
        timings[i][2] = avg_time
        total_time += avg_time * timings[i][1]

    return [head] + timings + [[], ["Total time", total_time]]


if __name__ == "__main__":
    logpath = sys.argv[1]
    log_timings = parse_log(logpath)

    timing_csv = logpath.replace(".log", ".csv")
    with open(timing_csv, "w", encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(log_timings)
