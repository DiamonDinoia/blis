# Translated from config/bgq/make_defs.mk (BLIS make-based build system).
# Included via blis_load_config_defs(<name>); variables available in scope:
#   CC_VENDOR CC GCC_OT_4_9_0 GCC_OT_6_1_0 GCC_OT_9_1_0 GCC_OT_10_3_0
#   CLANG_OT_9_0_0 CLANG_OT_12_0_0 AOCC_OT_2_0_0 AOCC_OT_3_0_0
#   DEBUG_TYPE OS_NAME IS_WIN
# Sets: CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
#       CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS
# May also set: LDFLAGS MK_ENABLE_MEMKIND (handled by caller).






































set(THIS_CONFIG "bgq")














set(CPPROCFLAGS "-I/bgsys/drivers/ppcfloor -I/bgsys/drivers/ppcfloor/spi/include/kernel/cnk")
if("${CC_VENDOR}" STREQUAL "ibm")
set(CMISCFLAGS "-qthreaded -qsmp=omp -qasm=gcc -qkeyword=asm")
elseif("${CC_VENDOR}" STREQUAL "clang")
set(CMISCFLAGS "-fopenmp")
else()
blis_defer_error("xlc or bgclang is required for this configuration.")
endif()
set(CPICFLAGS "-fPIC")
set(CWARNFLAGS "-w")

if(NOT "${DEBUG_TYPE}" STREQUAL "off")
set(CDBGFLAGS "-g")
endif()

if("${DEBUG_TYPE}" STREQUAL "noopt")
set(COPTFLAGS "-O0")
else()
set(COPTFLAGS "-O2")
endif()


set(CKOPTFLAGS "${COPTFLAGS} -O3")
if("${CC_VENDOR}" STREQUAL "ibm")
set(CKVECFLAGS "-qarch=qp -qtune=qp -qsimd=auto -qhot=level=1 -qprefetch -qunroll=yes -qnoipa")
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


if("${CC_VENDOR}" STREQUAL "ibm")
set(LDFLAGS "-L/bgsys/drivers/ppcfloor/spi/lib -lSPI -lSPI_cnk -qthreaded -qsmp=omp")
elseif("${CC_VENDOR}" STREQUAL "clang")
set(LDFLAGS "-L/bgsys/drivers/ppcfloor/spi/lib -lSPI -lSPI_cnk -fopenmp")
endif()




