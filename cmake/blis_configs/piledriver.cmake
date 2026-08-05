# Translated from config/piledriver/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "piledriver")









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


set(CKOPTFLAGS "${COPTFLAGS} -O3")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CKVECFLAGS "-mfpmath=sse -mavx -mfma -march=bdver2 -mno-fma4 -mno-tbm -mno-xop -mno-lwp")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CKVECFLAGS "-mfpmath=sse -mavx -mfma -march=bdver2 -mno-fma4 -mno-tbm -mno-xop -mno-lwp")
else()
if("${CC_VENDOR}" STREQUAL "NVIDIA")
set(CKVECFLAGS "-march=piledriver -fast -mno-fma4 -mno-tbm -mno-xop -mno-lwp")
else()
blis_defer_error("gcc, clang, or nvc is required for this configuration.")
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




