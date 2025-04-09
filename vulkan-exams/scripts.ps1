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
# Do note that z=xy^t. x=(m,k) is weight and y=(n,k) is input
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_RUN_TESTS=ON
cmake --build build --config Release
.\llama-bench -p 100 -n 0 -r 1 --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_gemm_fmatest_f16war_dumcomploop.log

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

# ASM Analysis
$SHADER_INCLUDE_PATH="C:\SRC\llama.cpp\ggml\src\ggml-vulkan\vulkan-shaders"
$MM_SHADER_DEFINES="-DFLOAT16 -DDATA_A_Q4_K -DLOAD_VEC_A=2 -DLOAD_VEC_B=8 -DB_TYPE=mat2x4 -DFLOAT_TYPE=float16_t -DD_TYPE=float -DACC_TYPE=float16_t"
$INPUT_COMP="C:\SRC\llama.cpp\ggml\src\ggml-vulkan\vulkan-shaders\mul_mm.comp"
$OUTSPV="matmul_q4_k_f32_f16acc_aligned_m"

# glslangValidator
glslangValidator -V -DF16VEC2_WAR -DFLOAT16 -DDATA_A_Q4_K -DLOAD_VEC_A=2 -DLOAD_VEC_B=8 -DB_TYPE=mat2x4 -DFLOAT_TYPE=float16_t -DD_TYPE=float -DACC_TYPE=f16vec2 -IC:\SRC\llama.cpp\ggml\src\ggml-vulkan\vulkan-shaders mul_mm.comp -o matmul_q4_k_f32_f16acc_aligned_m_f16vec2war.spv
spirv-dis matmul_q4_k_f32_f16acc_aligned_m_f16vec2war.spv -o matmul_q4_k_f32_f16acc_aligned_m_f16vec2war.asm

# RGA
# C:\SRC\RadeonDeveloperToolSuite-2025-03-07-1606\rga.exe
./rga.exe -s vulkan -h
./rga.exe -s vulkan -c gfx1150 ${MM_SHADER_DEFINES} -I ${SHADER_INCLUDE_PATH} --comp ${INPUT_COMP}
# Use RGA Layer for .cpso file
$Env:RGA_LAYER_OUTPUT_PATH="C:\SRC\Radeon\RGA\Layer"
$Env:ENABLE_RGA_PIPELINE_EXTRACTION_LAYER="1"
$Env:RGA_LAYER_LOG_ENABLE="1" # Enable logging for debugging
# Run your Vulkan® application with the above environment variables set.
# The layer will generate the output files in RGA_LAYER_OUTPUT_PATH.

# FLOAT16;DATA_A_Q4_K;LOAD_VEC_A=2;LOAD_VEC_B=8;B_TYPE=mat2x4;FLOAT_TYPE=float16_t;D_TYPE=float;ACC_TYPE=float16_t;F16VEC2_WAR2