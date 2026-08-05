# Translated from config/knl/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "knl")









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

if("${DEBUG_TYPE}" STREQUAL "sde")



set(CPPROCFLAGS "${CPPROCFLAGS} -DBLIS_DISABLE_MEMKIND")




set(MK_ENABLE_MEMKIND "no")
endif()


set(CKOPTFLAGS "${COPTFLAGS} -O3")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CKVECFLAGS "-mavx512f -mavx512pf -mfpmath=sse -march=knl")
else()
if("${CC_VENDOR}" STREQUAL "icc")
set(CKVECFLAGS "-xMIC-AVX512")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CKVECFLAGS "-mavx512f -mavx512pf -mfpmath=sse -march=knl")
else()
blis_defer_error("gcc, icc, or clang is required for this configuration.")
endif()
endif()
endif()


if(NOT "${CC_VENDOR}" STREQUAL "icc")
if("${OS_NAME}" STREQUAL "Darwin")
set(CKVECFLAGS "${CKVECFLAGS} -Wa,-march=knl")
endif()
endif()



set(CROPTFLAGS "${CKOPTFLAGS}")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CRVECFLAGS "-march=knl -mno-avx512f -mno-avx512pf -mno-avx512er -mno-avx512cd -funsafe-math-optimizations -ffp-contract=fast")
else()
if("${CC_VENDOR}" STREQUAL "icc")
set(CRVECFLAGS "-xMIC-AVX512")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CRVECFLAGS "-march=knl -mno-avx512f -mno-avx512pf -mno-avx512er -mno-avx512cd -funsafe-math-optimizations -ffp-contract=fast")
else()
blis_defer_error("gcc, icc, or clang is required for this configuration.")
endif()
endif()
endif()




