# Build Env is MSYS2 UCRT64
# Use modified llama-bench.cpp and ggml-vulkan.cpp
# For igpu, setup device = 1
$Env:GGML_VK_VISIBLE_DEVICES="1"
$LOG_DIR="C:\SRC\llama.cpp\vulkan-exams\logs"
$MODEL_DIR="C:\SRC\llmodel\Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf"

Set-Location .\llama.cpp\build\bin

# 1. E2E Benchmark
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release
.\llama-bench -p 0 -n 0 -r 10 -pg 128,128 -pg 128,2048 -pg 2048,128 -pg 2048,2048 -m $MODEL_DIR *>> $LOG_DIR\vulkan_e2e_perf_01.log

# 2. Get the vulkan debug log
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_DEBUG=ON
cmake --build build --config Release
.\llama-bench -p 512 -n 0 -r 1 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_debug_p512_n0_01.log
.\llama-bench -p 100 -n 1 -r 1 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_debug_p100_n1_01.log

# 3. GEMM Benchmark
# Do not needs debug option
# Modify ggml-vulkan.cpp(7816): const std::vector<size_t> vals for GEMM benchmark
# Do note that z=xy^t. x=(m,k) is weight and y=(n,k) is input.
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_RUN_TESTS=ON
cmake --build build --config Release
.\llama-bench -p 100 -n 0 -r 1 --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_gemm_test_fixmn_shmook.log

# 4. Profile
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_PERF=ON
cmake --build build --config Release
# Modify ggml-vulkan.cpp(8204): int nps[3] = {0, 0, 0} for per-nodes profiling
.\llama-bench -p 128 -n 0 -r 10 --progress -m $MODEL_DIR *> $LOG_DIR\vulkan_profile_p128_n0_01.log
.\llama-bench -p 1024 -ub 1024 -n 0 -r 20 --progress -m $MODEL_DIR *> $LOG_DIR\vulkan_profile_p1024_n0_03.log
.\llama-bench -p 0 -n 1 -r 20 --progress -m $MODEL_DIR *> $LOG_DIR\vulkan_profile_p0_n1_01.log

# 5. DEBUG
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DGGML_VULKAN=ON -DGGML_VULKAN_DEBUG=OFF -DGGML_VULKAN_PERF=ON # or -DGGML_VULKAN_RUN_TESTS=ON
cmake --build build --config Debug
# edit lauch.json for debugging.

# 0. Parse timings
python ..\..\vulkan-exams\parse_log.py $LOG_DIR\vulkan_gemm_test_cta256.log
python parse_log.py $LOG_DIR\vulkan_gemm_01.log


# Do note that the logged ops only contains op+shape informations. Needs to denote the layer name maunally.