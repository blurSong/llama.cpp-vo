
# Use modified llama-bench.cpp
# Benchmark
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_PERF=OFF
cmake --build build --config Release

LOG_DIR="D:\SRCs\llama.cpp\vulkan-exams\logs"

Set-Location .\build\bin
.\llama-bench -p 0 -n 0 -r 10 -pg 128,128 -pg 128,2048 -pg 2048,128 -pg 2048,2048 -mg 0 -m C:\SRC\llmodel\Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf *> $LOG_DIR\vulkan-perf_01.log

# Profile
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_PERF=ON
cmake --build build --config Release
Set-Location .\build\bin
.\llama-bench -p 128 -n 0 -r 20 -mg 0 --progress --skip-warmup -m C:\SRC\llmodel\Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf *> $LOG_DIR\vulkan-perf_p128_n0_01.log
.\llama-bench -p 0 -n 128 -r 1 -mg 0 --progress --skip-warmup -m C:\SRC\llmodel\Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf *> $LOG_DIR\vulkan-perf_p0_n128_01.log
.\llama-bench -p 1024 -ub 1024 -n 0 -r 1 -mg 0 --progress --skip-warmup -m C:\SRC\llmodel\Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf *> $LOG_DIR\vulkan-perf_p128_n0_01.log

# Parse timings
python parse_timings.py logs\vulkan_perf_p128_n0_01.log