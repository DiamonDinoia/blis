# Translated from config/altramax/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "altramax")









set(CPPROCFLAGS "-D_GNU_SOURCE")
set(CMISCFLAGS "")
set(CPICFLAGS "")
set(CWARNFLAGS "")

if(NOT "${DEBUG_TYPE}" STREQUAL "off")
set(CDBGFLAGS "-g")
endif()

if("${DEBUG_TYPE}" STREQUAL "noopt")
set(COPTFLAGS "-O0")
else()
set(COPTFLAGS "-O2 -mcpu=neoverse-n1")
endif()


set(CKOPTFLAGS "${COPTFLAGS} -O3 -ftree-vectorize")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CKVECFLAGS "-mcpu=neoverse-n1")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CKVECFLAGS "-mcpu=neoverse-n1")
else()
blis_defer_error("gcc or clang is required for this configuration.")
endif()
endif()


set(CROPTFLAGS "${CKOPTFLAGS}")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CRVECFLAGS "${CKVECFLAGS}")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CRVECFLAGS "${CKVECFLAGS}")
else()
set(CRVECFLAGS "${CKVECFLAGS}")
endif()
endif()




