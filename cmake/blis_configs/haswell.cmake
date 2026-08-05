# Translated from config/haswell/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "haswell")









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
set(CKVECFLAGS "-mavx2 -mfma -mfpmath=sse -march=haswell")
if("${GCC_OT_4_9_0}" STREQUAL "yes")

set(CKVECFLAGS "-mavx2 -mfma -mfpmath=sse -march=core-avx2")
endif()
else()
if("${CC_VENDOR}" STREQUAL "icc")
set(CKVECFLAGS "-xCORE-AVX2")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CKVECFLAGS "-mavx2 -mfma -mfpmath=sse -march=haswell")
else()
if("${CC_VENDOR}" STREQUAL "NVIDIA")
set(CKVECFLAGS "-march=haswell -fast")
else()
blis_defer_error("gcc, icc, clang, or nvc is required for this configuration.")
endif()
endif()
endif()
endif()


set(CROPTFLAGS "${CKOPTFLAGS}")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CRVECFLAGS "${CKVECFLAGS} -funsafe-math-optimizations -ffp-contract=fast")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CRVECFLAGS "${CKVECFLAGS} -funsafe-math-optimizations -ffp-contract=fast")
else()
set(CRVECFLAGS "${CKVECFLAGS}")
endif()
endif()




