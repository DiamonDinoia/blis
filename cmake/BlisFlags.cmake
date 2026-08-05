# Loads cmake/blis_configs/<c>.cmake (translated make_defs.mk) and assembles
# the per-class compiler flags exactly as common.mk's get-*-cflags-for do.
#
# Inputs expected in scope: BLIS_CC_VENDOR, CC compiler id/version booleans
# (BLIS_GCC_OT_* etc.), BLIS_DEBUG_TYPE_RES (off/noopt/opt/sde lowercase),
# host OS thread flags BLIS_CTHREADFLAGS, and the def file directory.
#
# Provides:
#   blis_load_config_defs(<cfg>)        -> BLIS_DEFS_<VAR>_<cfg> parent-scope vars
#   blis_finalize_config_defs(<cfg>)    -> global flag appends (warn/lang/proc/pic)
#   blis_get_cflags(<cfg> <class> <out>) -> flag list; class in
#       frame config kernel refinit refkern addon addon-kernel sandbox user

# Bridge variables for the def files (make naming, "yes"/"no" strings).
set(CC "${CMAKE_C_COMPILER}")
set(CC_VENDOR "${BLIS_CC_VENDOR}")
set(OS_NAME "${BLIS_HOST_OS}")
set(IS_WIN "${BLIS_IS_WIN}")
set(DEBUG_TYPE "${BLIS_DEBUG_TYPE}")
foreach(v 4_9_0 6_1_0 9_1_0 10_3_0)
  set(GCC_OT_${v} "${BLIS_GCC_OT_${v}}")
endforeach()
set(CLANG_OT_9_0_0 "${BLIS_CLANG_OT_9_0_0}")
set(CLANG_OT_12_0_0 "${BLIS_CLANG_OT_12_0_0}")
set(AOCC_OT_2_0_0 "${BLIS_AOCC_OT_2_0_0}")
set(AOCC_OT_3_0_0 "${BLIS_AOCC_OT_3_0_0}")

# LDFLAGS is captured because some configs append to the link line
# (rv* => -latomic; bgq => SPI libs). The make-defs' per-config
# MK_ENABLE_MEMKIND override is intentionally NOT honored at link time:
# the make system never reads it there either (common.mk computes LDFLAGS
# before including the defs); knl's en-masse '-DBLIS_DISABLE_MEMKIND'
# CPPROCFLAGS define still applies (config/knl def file).
set(_BLIS_DEF_VARS
  CPPROCFLAGS CMISCFLAGS CPICFLAGS CWARNFLAGS CDBGFLAGS COPTFLAGS
  CKOPTFLAGS CKVECFLAGS CROPTFLAGS CRVECFLAGS LDFLAGS)

function(blis_load_config_defs cfg)
  if(NOT EXISTS "${BLIS_SOURCE_DIR}/cmake/blis_configs/${cfg}.cmake")
    message(FATAL_ERROR "BLIS: no flag definitions for config '${cfg}'")
  endif()
  # Init LDFLAGS/MK_ENABLE_MEMKIND capture to empty so stale parent values
  # never leak across configs.
  set(LDFLAGS "")
  include("${BLIS_SOURCE_DIR}/cmake/blis_configs/${cfg}.cmake")
  foreach(v ${_BLIS_DEF_VARS})
    separate_arguments(_l UNIX_COMMAND "${${v}}")
    set(BLIS_DEFS_${v}_${cfg} "${_l}" PARENT_SCOPE)
  endforeach()
endfunction()

# Global appends (common.mk "Configuration-agnostic flags" section). make
# appends the global value onto each config's stored value; MSVC empties PIC.
function(blis_finalize_config_defs cfg)
  set(cwarn ${BLIS_DEFS_CWARNFLAGS_${cfg}} ${BLIS_GLOBAL_CWARNFLAGS})
  set(clang -std=c99)
  set(cproc ${BLIS_DEFS_CPPROCFLAGS_${cfg}} ${BLIS_GLOBAL_CPPFLAGS})
  set(cpic ${BLIS_DEFS_CPICFLAGS_${cfg}})
  if(MSVC)
    set(cpic "")
  endif()
  set(BLIS_DEFS_CWARNFLAGS_${cfg} "${cwarn}" PARENT_SCOPE)
  set(BLIS_DEFS_CLANGFLAGS_${cfg} "${clang}" PARENT_SCOPE)
  set(BLIS_DEFS_CPPROCFLAGS_${cfg} "${cproc}" PARENT_SCOPE)
  set(BLIS_DEFS_CPICFLAGS_${cfg} "${cpic}" PARENT_SCOPE)
endfunction()

# CXX counterpart (common.mk get-noopt-cxxflags-for chain): no CLANGFLAGS,
# and CXXLANGFLAGS (-std=c++11, or c++17 with HPX) instead. Classes map 1:1;
# addon-kernel CXX gets CKOPT/CKVEC like its C counterpart.
function(blis_get_cxxflags cfg class out)
  set(f ${BLIS_CXXFLAGS_PRESET}
        ${BLIS_DEFS_CDBGFLAGS_${cfg}}
        ${BLIS_DEFS_CWARNFLAGS_${cfg}}
        ${BLIS_DEFS_CPICFLAGS_${cfg}}
        ${BLIS_DEFS_CMISCFLAGS_${cfg}}
        ${BLIS_DEFS_CPPROCFLAGS_${cfg}}
        ${BLIS_CXXLANGFLAGS}
        ${BLIS_CTHREADFLAGS})
  string(TOUPPER "${cfg}" CFGU)
  if(class STREQUAL "frame")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "config")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "kernel" OR class STREQUAL "addon-kernel")
    list(APPEND f ${BLIS_DEFS_CKOPTFLAGS_${cfg}} ${BLIS_DEFS_CKVECFLAGS_${cfg}}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "refinit")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS}
                  -DBLIS_IN_REF_KERNEL=1
                  -include "${BLIS_SOURCE_DIR}/config/${cfg}/bli_kernel_defs_${cfg}.h")
  elseif(class STREQUAL "refkern")
    list(APPEND f ${BLIS_DEFS_CROPTFLAGS_${cfg}} ${BLIS_DEFS_CRVECFLAGS_${cfg}}
                  ${BLIS_COMPSIMDFLAGS}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS}
                  -DBLIS_IN_REF_KERNEL=1
                  -include "${BLIS_SOURCE_DIR}/config/${cfg}/bli_kernel_defs_${cfg}.h")
  elseif(class STREQUAL "addon" OR class STREQUAL "sandbox")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "user")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}})
  else()
    message(FATAL_ERROR "blis_get_cxxflags: unknown class '${class}'")
  endif()
  set(${out} "${f}" PARENT_SCOPE)
endfunction()

# Assemble the final flag list. Mirrors get-noopt-cflags-for + per-class
# appends. Include dirs and -D defines are handled by the caller except for
# class-specific -D flags, which are included here for exact parity.
function(blis_get_cflags cfg class out)
  set(f ${BLIS_CFLAGS_PRESET}
        ${BLIS_DEFS_CDBGFLAGS_${cfg}}
        ${BLIS_DEFS_CWARNFLAGS_${cfg}}
        ${BLIS_DEFS_CPICFLAGS_${cfg}}
        ${BLIS_DEFS_CMISCFLAGS_${cfg}}
        ${BLIS_DEFS_CLANGFLAGS_${cfg}}
        ${BLIS_DEFS_CPPROCFLAGS_${cfg}}
        ${BLIS_CTHREADFLAGS})
  string(TOUPPER "${cfg}" CFGU)
  if(class STREQUAL "frame")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "config")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "kernel")
    list(APPEND f ${BLIS_DEFS_CKOPTFLAGS_${cfg}} ${BLIS_DEFS_CKVECFLAGS_${cfg}}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "refinit")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS}
                  -DBLIS_IN_REF_KERNEL=1
                  -include "${BLIS_SOURCE_DIR}/config/${cfg}/bli_kernel_defs_${cfg}.h")
  elseif(class STREQUAL "refkern")
    list(APPEND f ${BLIS_DEFS_CROPTFLAGS_${cfg}} ${BLIS_DEFS_CRVECFLAGS_${cfg}}
                  ${BLIS_COMPSIMDFLAGS}
                  -DBLIS_CNAME=${cfg} -DBLIS_CNAME_UPPER=${CFGU} ${BLIS_ASANFLAGS}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS}
                  -DBLIS_IN_REF_KERNEL=1
                  -include "${BLIS_SOURCE_DIR}/config/${cfg}/bli_kernel_defs_${cfg}.h")
  elseif(class STREQUAL "addon")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "addon-kernel")
    list(APPEND f ${BLIS_DEFS_CKOPTFLAGS_${cfg}} ${BLIS_DEFS_CKVECFLAGS_${cfg}}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "sandbox")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}}
                  -DBLIS_IS_BUILDING_LIBRARY ${BLIS_SYMFLAGS})
  elseif(class STREQUAL "user")
    list(APPEND f ${BLIS_DEFS_COPTFLAGS_${cfg}})
  else()
    message(FATAL_ERROR "blis_get_cflags: unknown class '${class}'")
  endif()
  set(${out} "${f}" PARENT_SCOPE)
endfunction()
