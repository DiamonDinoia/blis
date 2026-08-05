# Translated from config/rv64iv/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "rv64iv")









set(CPPROCFLAGS "-DRISCV_SIZE=64")

execute_process(COMMAND "${CC}" -DFORCE_RISCV_VECTOR -E "${BLIS_SOURCE_DIR}/build/detect/riscv/bli_riscv_detect_arch.h" OUTPUT_VARIABLE _rv_out OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX MATCHALL "(^|\n)[^#\n][^\n]*" _rv_lines "${_rv_out}")
string(REGEX REPLACE "[\n \t]" "" _rv_lines "${_rv_lines}")
set(RISCV_ARCH "${_rv_lines}")
execute_process(COMMAND "${CC}" -DFORCE_RISCV_VECTOR -E "${BLIS_SOURCE_DIR}/build/detect/riscv/bli_riscv_detect_abi.h" OUTPUT_VARIABLE _rv_out OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX MATCHALL "(^|\n)[^#\n][^\n]*" _rv_lines "${_rv_out}")
string(REGEX REPLACE "[\n \t]" "" _rv_lines "${_rv_lines}")
set(RISCV_ABI "${_rv_lines}")

if(NOT RISCV_ARCH MATCHES "64")
blis_defer_error("The RISC-V compiler architecture ${RISCV_ARCH} is not compatible with ${THIS_CONFIG}")
elseif(NOT RISCV_ABI MATCHES "64")
blis_defer_error("The RISC-V compiler ABI ${RISCV_ABI} is not compatible with ${THIS_CONFIG}")
endif()

set(CMISCFLAGS "-march=${RISCV_ARCH} -mabi=${RISCV_ABI}")
set(CPICFLAGS "-fPIC")
set(CWARNFLAGS "-Wall -Wno-unused-function -Wfatal-errors")


set(LDFLAGS "${LDFLAGS} -latomic")

if(NOT "${DEBUG_TYPE}" STREQUAL "off")
set(CDBGFLAGS "-g")
endif()

if("${DEBUG_TYPE}" STREQUAL "noopt")
set(COPTFLAGS "-O0")
else()
set(COPTFLAGS "-O2 -ftree-vectorize")
endif()


set(CKOPTFLAGS "${COPTFLAGS} -O3")
if("${CC_VENDOR}" STREQUAL "gcc")
set(CKVECFLAGS "")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CKVECFLAGS "")
else()
blis_defer_error("gcc or clang is required for this configuration.")
endif()
endif()


set(CROPTFLAGS "${CKOPTFLAGS}")
if("${CC_VENDOR}" STREQUAL "gcc")

set(CRVECFLAGS "${CKVECFLAGS} -O0")
else()
if("${CC_VENDOR}" STREQUAL "clang")
set(CRVECFLAGS "${CKVECFLAGS} -funsafe-math-optimizations -ffp-contract=fast")
else()
set(CRVECFLAGS "${CKVECFLAGS}")
endif()
endif()



