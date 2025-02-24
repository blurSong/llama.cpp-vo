
# Use modified llama-bench.cpp
# To setup device 1 for igpu
$Env:GGML_VK_VISIBLE_DEVICES="1"

$LOG_DIR="C:\SRC\llama.cpp\vulkan-exams\logs"
$MODEL_DIR="C:\SRC\llmodel\Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf"

Set-Location .\build\bin

# E2E Benchmark MSYS2 UCRT64
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_PERF=OFF
cmake --build build --config Release

.\llama-bench -p 0 -n 0 -r 10 -pg 128,128 -pg 128,2048 -pg 2048,128 -pg 2048,2048 -m $MODEL_DIR *> $LOG_DIR\vulkan-perf_01.log
.\llama-bench -p 512 -n 0 -r 1 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_gemm_01.log

# GEMM Benchmark MSYS2 UCRT64   
# Do not needs debug option
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_RUN_TESTS=ON 
cmake --build build --config Release
.\llama-bench -p 100 -n 0 -r 1 --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan-perf_01.log

# Profile MSYS2 UCRT64
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_PERF=ON
cmake --build build --config Release

.\llama-bench -p 128 -n 0 -r 21 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_perf_p128_n0_01.log
.\llama-bench -p 0 -n 128 -r 21 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_perf_p0_n128_03.log
.\llama-bench -p 1024 -ub 1024 -n 0 -r 21 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_perf_p1024_n0_03.log

# Parse timings
python parse_timings.py $LOG_DIR\vulkan_perf_p128_n0_03.log short

# Do note that the logged ops only contains op+shape informations. Needs to denote the layer name maunally.