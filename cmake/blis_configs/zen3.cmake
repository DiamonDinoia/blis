# Translated from config/zen3/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "zen3")









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
set(COPTFLAGS "-O3")
endif()




set(CKOPTFLAGS "${COPTFLAGS} -fomit-frame-pointer")
set(CROPTFLAGS "${CKOPTFLAGS}")
set(CKVECFLAGS "-mavx2 -mfma")
set(CRVECFLAGS "${CKVECFLAGS}")
if("${CC_VENDOR}" STREQUAL "gcc")
if("${GCC_OT_9_1_0}" STREQUAL "yes")
set(CVECFLAGS_VER "-march=znver1 -mno-avx256-split-unaligned-store")
else()
if("${GCC_OT_10_3_0}" STREQUAL "yes")
set(CVECFLAGS_VER "-march=znver2")
else()
set(CVECFLAGS_VER "-march=znver3")
endif()
endif()
set(CKVECFLAGS "${CKVECFLAGS} -mfpmath=sse")
set(CRVECFLAGS "${CRVECFLAGS} -funsafe-math-optimizations -ffp-contract=fast")
else()
if("${CC_VENDOR}" STREQUAL "clang")
if("${CLANG_OT_9_0_0}" STREQUAL "yes")
set(CVECFLAGS_VER "-march=znver1")
else()
if("${CLANG_OT_12_0_0}" STREQUAL "yes")
set(CVECFLAGS_VER "-march=znver2")
else()
if("${OS_NAME}" STREQUAL "Darwin")
set(CVECFLAGS_VER "-march=znver2")
else()
set(CVECFLAGS_VER "-march=znver3")
endif()
endif()
endif()
set(CKVECFLAGS "${CKVECFLAGS} -mfpmath=sse")
set(CRVECFLAGS "${CRVECFLAGS} -funsafe-math-optimizations -ffp-contract=fast")
else()
if("${CC_VENDOR}" STREQUAL "aocc")
if("${AOCC_OT_2_0_0}" STREQUAL "yes")
set(CVECFLAGS_VER "-march=znver1")
else()
if("${AOCC_OT_3_0_0}" STREQUAL "yes")
set(CVECFLAGS_VER "-march=znver2")
else()
set(CVECFLAGS_VER "-march=znver3")
endif()
endif()
set(CKVECFLAGS "${CKVECFLAGS} -mfpmath=sse")
set(CRVECFLAGS "${CRVECFLAGS} -funsafe-math-optimizations -ffp-contract=fast")
if("${CC_VENDOR}" STREQUAL "NVIDIA")
set(CVECFLAGS_VER "-march=znver3")
set(CRVECFLAGS "${CRVECFLAGS} -fast")
else()
blis_defer_error("gcc, clang, nvc or aocc is required for this configuration.")
endif()
endif()
endif()
endif()
set(CKVECFLAGS "${CKVECFLAGS} ${CVECFLAGS_VER}")
set(CRVECFLAGS "${CRVECFLAGS} ${CVECFLAGS_VER}")



