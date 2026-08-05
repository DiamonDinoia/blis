# Translated from config/sifive_rvv/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); see sibling files for the
# variable scope contract.

set(THIS_CONFIG "sifive_rvv")

set(CMISCFLAGS_SIFIVE "-mcmodel=medany -march=rv64gcv_zba_zbb -mabi=lp64d")
set(CMISCFLAGS_SIFIVE_OTHER "")
set(CPPROCFLAGS "")
set(CMISCFLAGS "${CMISCFLAGS_SIFIVE} ${CMISCFLAGS_SIFIVE_OTHER} -fdata-sections -ffunction-sections -fdiagnostics-color=always -fno-rtti -fno-exceptions")
set(CPICFLAGS "-fPIC")
set(CWARNFLAGS "-Wall -Wextra -Wno-unused-function -Wno-unused-parameter -Wno-sign-compare -Wno-unused-variable")

if(NOT "${DEBUG_TYPE}" STREQUAL "off")
  set(CDBGFLAGS "-g")
endif()

if("${DEBUG_TYPE}" STREQUAL "noopt")
  set(COPTFLAGS "-O0")
else()
  set(COPTFLAGS "-O3")
endif()

set(CKOPTFLAGS "${COPTFLAGS}")
set(CKVECFLAGS "")

set(CROPTFLAGS "${CKOPTFLAGS}")
set(CRVECFLAGS "${CKVECFLAGS}")
