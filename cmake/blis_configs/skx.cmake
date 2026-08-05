# Translated from config/skx/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "skx")









set(CPPROCFLAGS "")
set(CMISCFLAGS "")
set(CPICFLAGS "-fPIC")
set(CWARNFLAGS "")

if(NOT "${DEBUG_TYPE}" STREQUAL "off")
set(CDBGFLAGS "-g")
endif()

if("${DEBUG_TYPE}" STREQUAL "noopt")
set(COPTFLAGS "-O0")
else()
set(COPTFLAGS "-O2")
endif()




set(CKOPTFLAGS "${COPTFLAGS} -O3 -fomit-frame-pointer")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CKVECFLAGS "-mavx512f -mavx512dq -mavx512bw -mavx512vl -mfpmath=sse -march=skylake-avx512")
else()
if("${CC_VENDOR}" STREQUAL "icc")
set(CKVECFLAGS "-xCORE-AVX512")
else()
if("${CC_VENDOR}" STREQUAL "clang")




if("${IS_WIN}" STREQUAL "yes")
set(CKVECFLAGS "-mavx512f -mavx512dq -mavx512bw -mavx512vl -mfpmath=sse -march=haswell")
else()
set(CKVECFLAGS "-mavx512f -mavx512dq -mavx512bw -mavx512vl -mfpmath=sse -march=skylake-avx512")
endif()
else()
if("${CC_VENDOR}" STREQUAL "NVIDIA")
set(CKVECFLAGS "-march=skylake -fast")
else()
blis_defer_error("gcc, icc, clang, or nvc is required for this configuration.")
endif()
endif()
endif()
endif()


if(NOT "${CC_VENDOR}" STREQUAL "icc")
if("${OS_NAME}" STREQUAL "Darwin")
set(CKVECFLAGS "${CKVECFLAGS} -Wa,-march=skylake-avx512")
endif()
endif()





set(CROPTFLAGS "${CKOPTFLAGS}")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CRVECFLAGS "-march=skylake-avx512 -mno-avx512f -mno-avx512vl -mno-avx512bw -mno-avx512dq -mno-avx512cd -funsafe-math-optimizations -ffp-contract=fast")
else()
if("${CC_VENDOR}" STREQUAL "icc")
set(CRVECFLAGS "-xCORE-AVX2")
else()
if("${CC_VENDOR}" STREQUAL "clang")




if("${IS_WIN}" STREQUAL "yes")
set(CRVECFLAGS "-march=haswell -funsafe-math-optimizations -ffp-contract=fast")
else()
set(CRVECFLAGS "-march=skylake-avx512 -mno-avx512f -mno-avx512vl -mno-avx512bw -mno-avx512dq -mno-avx512cd -funsafe-math-optimizations -ffp-contract=fast")
endif()
else()
if("${CC_VENDOR}" STREQUAL "NVIDIA")
set(CRVECFLAGS "-march=skylake -fast")
else()
blis_defer_error("gcc, icc, clang, or nvc is required for this configuration.")
endif()
endif()
endif()
endif()




