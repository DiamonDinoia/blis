# Compiler/vendor detection + capability probes, mirroring configure's
# check_compiler()/check_assembler()/check_os() and the memkind/omp_simd
# probes. Sets (parent scope):
#   BLIS_CC_VENDOR          gcc|clang|icc|aocc|NVIDIA|ibm
#   BLIS_APPLE_CLANG        yes|no
#   BLIS_GCC_OT_4_9_0 ... BLIS_GCC_OT_10_3_0     yes|no
#   BLIS_CLANG_OT_9_0_0 BLIS_CLANG_OT_12_0_0     yes|no
#   BLIS_AOCC_OT_2_0_0 BLIS_AOCC_OT_3_0_0        yes|no
#   BLIS_IS_WIN BLIS_IS_MSVC                     yes|no
#   BLIS_PRAGMA_OMP_SIMD                         yes|no
#   BLIS_HOST_OS / BLIS_HOST_MACHINE             uname-equivalents
#
# function blis_compute_blacklist(<out_var>) -> list of blacklisted
# subconfig names given the detected toolchain and host OS.

macro(_blis_set_yesno var cond)
  if(${cond})
    set(${var} yes)
  else()
    set(${var} no)
  endif()
endmacro()

set(BLIS_HOST_OS "${CMAKE_SYSTEM_NAME}")        # Linux, Darwin, Windows, ...
set(BLIS_HOST_MACHINE "${CMAKE_SYSTEM_PROCESSOR}")

if(WIN32 OR (CMAKE_C_COMPILER MATCHES "mingw|msys" ))
  set(BLIS_IS_WIN yes)
else()
  set(BLIS_IS_WIN no)
endif()
if(MSVC)
  set(BLIS_IS_MSVC yes)
else()
  set(BLIS_IS_MSVC no)
endif()

# --- vendor detection (parallel to configure's $CC --version parsing) ---
execute_process(COMMAND "${CMAKE_C_COMPILER}" --version
  OUTPUT_VARIABLE _cc_version OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)

set(BLIS_CC_VENDOR "")
set(BLIS_APPLE_CLANG no)
if(_cc_version MATCHES "AOCC")
  set(BLIS_CC_VENDOR aocc)
elseif(_cc_version MATCHES "Apple")
  set(BLIS_CC_VENDOR clang)
  set(BLIS_APPLE_CLANG yes)
elseif(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  set(BLIS_CC_VENDOR gcc)
elseif(CMAKE_C_COMPILER_ID MATCHES "^(Apple)?Clang$")
  set(BLIS_CC_VENDOR clang)
elseif(CMAKE_C_COMPILER_ID STREQUAL "Intel")
  set(BLIS_CC_VENDOR icc)
elseif(CMAKE_C_COMPILER_ID STREQUAL "IntelLLVM")
  set(BLIS_CC_VENDOR clang)      # icx: configure treats oneAPI as clang
elseif(CMAKE_C_COMPILER_ID STREQUAL "NVHPC")
  set(BLIS_CC_VENDOR NVIDIA)
elseif(CMAKE_C_COMPILER_ID STREQUAL "XL")
  set(BLIS_CC_VENDOR ibm)
else()
  message(FATAL_ERROR "BLIS: unsupported C compiler ${CMAKE_C_COMPILER_ID} (${CMAKE_C_COMPILER})")
endif()
message(STATUS "BLIS: C compiler vendor: ${BLIS_CC_VENDOR} (${CMAKE_C_COMPILER_VERSION})")

# --- version-range booleans (yes/no strings, like config.mk) ---
string(REPLACE "." ";" _cv "${CMAKE_C_COMPILER_VERSION}")
list(GET _cv 0 _vmaj)
list(GET _cv 1 _vmin)

if(BLIS_CC_VENDOR STREQUAL "gcc")
  _blis_set_yesno(BLIS_GCC_OT_4_9_0  "CMAKE_C_COMPILER_VERSION VERSION_LESS 4.9.0")
  _blis_set_yesno(BLIS_GCC_OT_6_1_0  "CMAKE_C_COMPILER_VERSION VERSION_LESS 6.1.0")
  _blis_set_yesno(BLIS_GCC_OT_9_1_0  "CMAKE_C_COMPILER_VERSION VERSION_LESS 9.1.0")
  _blis_set_yesno(BLIS_GCC_OT_10_3_0 "CMAKE_C_COMPILER_VERSION VERSION_LESS 10.3.0")
else()
  foreach(v 4_9_0 6_1_0 9_1_0 10_3_0)
    set(BLIS_GCC_OT_${v} no)
  endforeach()
endif()
if(BLIS_CC_VENDOR MATCHES "clang|aocc")
  _blis_set_yesno(BLIS_CLANG_OT_9_0_0  "CMAKE_C_COMPILER_VERSION VERSION_LESS 9.0.0")
  _blis_set_yesno(BLIS_CLANG_OT_12_0_0 "CMAKE_C_COMPILER_VERSION VERSION_LESS 12.0.0")
else()
  set(BLIS_CLANG_OT_9_0_0 no)
  set(BLIS_CLANG_OT_12_0_0 no)
endif()
if(BLIS_CC_VENDOR STREQUAL "aocc")
  _blis_set_yesno(BLIS_AOCC_OT_2_0_0 "CMAKE_C_COMPILER_VERSION VERSION_LESS 2.0.0")
  _blis_set_yesno(BLIS_AOCC_OT_3_0_0 "CMAKE_C_COMPILER_VERSION VERSION_LESS 3.0.0")
else()
  set(BLIS_AOCC_OT_2_0_0 no)
  set(BLIS_AOCC_OT_3_0_0 no)
endif()

# --- assembler ISA probes (configure's check_assembler) ---
# Try: cc -c build/detect/iset/<isa>.s ; clang gets a -march retry for avx512.
function(_blis_try_assemble isa out_var)
  set(_src "${BLIS_SOURCE_DIR}/build/detect/iset/${isa}.s")
  if(NOT EXISTS "${_src}")
    set(${out_var} FALSE PARENT_SCOPE)
    return()
  endif()
  set(_bin "${PROJECT_BINARY_DIR}/CMakeFiles/blis-detect-${isa}.o")
  execute_process(COMMAND "${CMAKE_C_COMPILER}" -c "${_src}" -o "${_bin}"
    RESULT_VARIABLE _rv OUTPUT_QUIET ERROR_QUIET)
  if(NOT _rv EQUAL 0 AND BLIS_CC_VENDOR STREQUAL "clang")
    if(isa STREQUAL "avx512f")
      execute_process(COMMAND "${CMAKE_C_COMPILER}" -march=knl -c "${_src}" -o "${_bin}"
        RESULT_VARIABLE _rv OUTPUT_QUIET ERROR_QUIET)
    elseif(isa STREQUAL "avx512dq")
      execute_process(COMMAND "${CMAKE_C_COMPILER}" -march=skylake-avx512 -c "${_src}" -o "${_bin}"
        RESULT_VARIABLE _rv OUTPUT_QUIET ERROR_QUIET)
    endif()
  endif()
  file(REMOVE "${_bin}")
  if(_rv EQUAL 0)
    set(${out_var} TRUE PARENT_SCOPE)
  else()
    set(${out_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

# --- #pragma omp simd support probe (configure's has_pragma_omp_simd) ---
function(_blis_probe_omp_simd out_var)
  set(_ok FALSE)
  if(BLIS_CC_VENDOR MATCHES "gcc|clang|icc")
    file(READ "${BLIS_SOURCE_DIR}/build/detect/omp_simd/omp_simd_detect.c" _src)
    if(BLIS_CC_VENDOR STREQUAL "icc")
      set(_flag "-qopenmp-simd")
    else()
      set(_flag "-fopenmp-simd")
    endif()
    set(_bin_dir "${PROJECT_BINARY_DIR}/CMakeFiles/omp-simd-probe")
    file(MAKE_DIRECTORY "${_bin_dir}")
    file(WRITE "${_bin_dir}/probe.c" "${_src}")
    execute_process(COMMAND "${CMAKE_C_COMPILER}" -std=c99 -O3 -march=native ${_flag}
                    -c "${_bin_dir}/probe.c" -o "${_bin_dir}/probe.o"
                    RESULT_VARIABLE _rv OUTPUT_QUIET ERROR_QUIET)
    file(REMOVE_RECURSE "${_bin_dir}")
    if(_rv EQUAL 0)
      set(_ok TRUE)
    endif()
  endif()
  set(${out_var} ${_ok} PARENT_SCOPE)
endfunction()

# --- memkind probe (configure's has_libmemkind) ---
function(_blis_probe_memkind out_var)
  set(_bin_dir "${PROJECT_BINARY_DIR}/CMakeFiles/memkind-probe")
  file(MAKE_DIRECTORY "${_bin_dir}")
  file(COPY "${BLIS_SOURCE_DIR}/build/detect/memkind/libmemkind_detect.c"
       DESTINATION "${_bin_dir}")
  execute_process(COMMAND "${CMAKE_C_COMPILER}"
                  "${_bin_dir}/libmemkind_detect.c" -lmemkind -o "${_bin_dir}/probe"
                  RESULT_VARIABLE _rv OUTPUT_QUIET ERROR_QUIET)
  file(REMOVE_RECURSE "${_bin_dir}")
  if(_rv EQUAL 0)
    set(${out_var} TRUE PARENT_SCOPE)
  else()
    set(${out_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

# --- blacklist computation (configure's check_compiler + check_assembler + check_os) ---
function(blis_compute_blacklist out_var)
  set(blacklist "")
  if(BLIS_CC_VENDOR STREQUAL "NVIDIA")
    list(APPEND blacklist knl)
  elseif(BLIS_CC_VENDOR STREQUAL "gcc")
    if(CMAKE_C_COMPILER_VERSION VERSION_LESS 4.7)
      message(FATAL_ERROR "BLIS requires gcc 4.7 or newer")
    endif()
    if(_vmaj EQUAL 4)
      list(APPEND blacklist knl)
    endif()
    if(CMAKE_C_COMPILER_VERSION VERSION_LESS 4.9)
      list(APPEND blacklist excavator zen)
    endif()
    if(CMAKE_C_COMPILER_VERSION VERSION_LESS 5 OR CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 15)
      list(APPEND blacklist knl)
    endif()
    if(CMAKE_C_COMPILER_VERSION VERSION_LESS 6)
      list(APPEND blacklist skx power9)
    endif()
    if(CMAKE_C_COMPILER_VERSION VERSION_LESS 10)
      list(APPEND blacklist armsve)
    endif()
  elseif(BLIS_CC_VENDOR STREQUAL "icc")
    if(CMAKE_C_COMPILER_VERSION VERSION_LESS 15)
      message(FATAL_ERROR "BLIS requires icc 15 or newer")
    endif()
    if(CMAKE_C_COMPILER_VERSION MATCHES "^15\\.0\\.")
      list(APPEND blacklist skx)
    endif()
    if(_vmaj EQUAL 18)
      message(WARNING "icc 18.x mis-compiles knl/skx kernels (upstream issue #371); disabling them")
      list(APPEND blacklist knl skx)
    endif()
    if(CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 19)
      message(FATAL_ERROR "BLIS does not support icc 19+; use icx (clang-based)")
    endif()
  elseif(BLIS_CC_VENDOR STREQUAL "aocc")
    # configure applies no config blacklist for aocc.
  elseif(BLIS_CC_VENDOR STREQUAL "clang")
    if(BLIS_APPLE_CLANG STREQUAL "yes")
      if(CMAKE_C_COMPILER_VERSION VERSION_LESS 5)
        message(FATAL_ERROR "BLIS requires Apple clang 5 or newer")
      endif()
      if(_vmaj EQUAL 5)
        list(APPEND blacklist excavator zen)
      endif()
      if(CMAKE_C_COMPILER_VERSION VERSION_LESS 7)
        list(APPEND blacklist knl skx)
      endif()
    else()
      if(CMAKE_C_COMPILER_VERSION VERSION_LESS 3)
        message(FATAL_ERROR "BLIS requires clang 3.3 or newer")
      endif()
      if(_vmaj EQUAL 3 AND CMAKE_C_COMPILER_VERSION VERSION_LESS 3.3)
        message(FATAL_ERROR "BLIS requires clang 3.3 or newer")
      endif()
      if(_vmaj EQUAL 3 AND CMAKE_C_COMPILER_VERSION VERSION_LESS 3.5)
        list(APPEND blacklist excavator zen)
      endif()
      if(_vmaj EQUAL 3 AND CMAKE_C_COMPILER_VERSION VERSION_LESS 3.9)
        list(APPEND blacklist knl skx)
      endif()
      if(CMAKE_C_COMPILER_VERSION VERSION_LESS 11)
        list(APPEND blacklist armsve)
      endif()
      if(CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 19)
        list(APPEND blacklist knl)
      endif()
    endif()
  endif()

  # Assembler capabilities.
  _blis_try_assemble(fma4 _ok4)
  _blis_try_assemble(avx _oka)
  _blis_try_assemble(fma3 _ok3)
  _blis_try_assemble(avx512f _okf)
  _blis_try_assemble(avx512dq _okd)
  if(NOT _ok4)
    list(APPEND blacklist bulldozer)
  endif()
  if(NOT _oka)
    list(APPEND blacklist sandybridge)
  endif()
  if(NOT _ok3)
    list(APPEND blacklist haswell piledriver steamroller excavator skx)
  endif()
  if(NOT _okf)
    list(APPEND blacklist knl skx)
  endif()
  if(NOT _okd)
    list(APPEND blacklist skx)
  endif()

  # OS / platform.
  if((BLIS_HOST_OS STREQUAL "Darwin" OR BLIS_IS_WIN STREQUAL "yes") AND BLIS_HOST_MACHINE MATCHES "arm64|aarch64")
    list(APPEND blacklist armsve)
  endif()

  if(blacklist)
    list(REMOVE_DUPLICATES blacklist)
  endif()
  set(${out_var} "${blacklist}" PARENT_SCOPE)
endfunction()

# configure accepts a config whose make_defs.mk calls $(error); make fails only
# when the build starts. Mirror that: the first deferred error fails the build.
# The end of the top-level CMakeLists.txt makes every other target depend on
# blis_config_error.
function(blis_defer_error msg)
  if(NOT TARGET blis_config_error)
    add_custom_target(blis_config_error ALL VERBATIM
      COMMAND ${CMAKE_COMMAND} -E echo "*** ${msg}.  Stop."
      COMMAND ${CMAKE_COMMAND} -E false)
  endif()
endfunction()
