##  Build in MSYS2 UCRT64
##  Use modified llama-bench.cpp and ggml-vulkan.cpp For igpu, setup device = 0
##  ---------------------------------------------------------------------------
# DeepSeek-R1-Distill-Llama-8B-Q4_K_M
# qwen\qwen2.5-7b-instruct-q4_k_m-00001-of-00002
# Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf

$Env:GGML_VK_VISIBLE_DEVICES="0"
$LOG_DIR="C:\SRC\llama.cpp\vulkan-exams\logs"
$MODEL_DIR="C:\SRC\llmodel\gguf\Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf"

# 1. E2E Benchmark
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release
.\llama-bench -p 0 -n 0 -r 10 -pg 128,128 -pg 512,128 -pg 1024,128 -pg 2048,128 -m $MODEL_DIR
.\llama-bench -m $MODEL_DIR -p 0 -n 0 -r 10 -ngl 999 -pg 21,512 # -fa 1

# 2. Get the vulkan debug log
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_DEBUG=ON
cmake --build build --config Release
.\llama-bench -p 512 -n 0 -r 1 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_debug_p512_n0_01.log
.\llama-bench -p 100 -n 1 -r 1 --progress --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_debug_p100_n1_01.log

# 3. GEMM Benchmark
# Do not needs -DGGML_VULKAN_DEBUG=ON
# Modify ggml-vulkan.cpp(7816): const std::vector<size_t> vals for GEMM benchmark
# Do note that z=xy^t. x=(m,k) is weight and y=(n,k) is input
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_RUN_TESTS=ON
cmake --build build --config Release
.\llama-bench -p 100 -n 0 -r 1 --skip-warmup -m $MODEL_DIR *> $LOG_DIR\vulkan_gemm_fmatest_f16war_dumcomploop.log

# 4. Profile
cmake -B build -DGGML_VULKAN=ON -DGGML_VULKAN_PERF=ON
cmake --build build --config Release
# Modify ggml-vulka.cpp nodes_per_submit=0 for profile perlayer
.\llama-bench -p 128 -n 0 -r 10 --progress -m $MODEL_DIR *> $LOG_DIR\vulkan_prefill.log
.\llama-bench -p 1024 -ub 1024 -n 0 -r 10 --progress -m $MODEL_DIR *> $LOG_DIR\vulkan_prefill.log
.\llama-bench -p 0 -n 0 -ub 2048 -pg 2048,1 -r 10 --progress -m $MODEL_DIR *> $LOG_DIR\vulkan_prefill_2048_decode_1_01.log

# Parse timings
# Do note that the logged ops only contains op+shape informations. Needs to denote the layer name maunally.
python ..\..\vulkan-exams\parse_log.py $LOG_DIR\decode.log

# 5. DEBUG
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DGGML_VULKAN=ON -DGGML_VULKAN_DEBUG=OFF # then add -DGGML_VULKAN_PERF=ON for profile or -DGGML_VULKAN_RUN_TESTS=ON for gemm
cmake --build build --config Debug
# edit lauch.json for debugging.


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