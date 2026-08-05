cmake_minimum_required(VERSION 4.0)

# configure honors AR, RANLIB and PYTHON from the environment, splits the value
# on whitespace (program first, then arguments), records the raw string in
# config.mk and exits 1 when the program is missing. Do the same: seed the cache
# before project() so CMake's own find_program keeps the program, keep the raw
# string in the cache entry BLIS_<T>_CMD (CMake's automatic reconfigure runs
# without the environment), and put the arguments into the archive rules and the
# python commands below. An explicit -D value wins and takes no arguments.
# shortcut: arguments are split on whitespace like configure's unquoted ${tool}; no shell quoting.
set(_blis_envs AR RANLIB PYTHON)
set(_blis_vars CMAKE_AR CMAKE_RANLIB Python3_EXECUTABLE)
set(_blis_descs "library archiver" "archive indexer" "python interpreter")
foreach(_t _v _d IN ZIP_LISTS _blis_envs _blis_vars _blis_descs)
  get_property(_blis_help CACHE ${_v} PROPERTY HELPSTRING)
  # Seed when unset, or again when an earlier run seeded it (reconfigure keeps the arguments).
  if(NOT "$ENV{${_t}}" STREQUAL "" AND (NOT DEFINED ${_v} OR _blis_help STREQUAL "${_t} from the environment"))
    separate_arguments(_blis_words UNIX_COMMAND "$ENV{${_t}}")
    list(POP_FRONT _blis_words _blis_prog)
    find_program(_blis_env_${_t} NAMES "${_blis_prog}" NO_CACHE)
    if(NOT _blis_env_${_t})
      message(FATAL_ERROR
        "BLIS: *** Could not find the ${_d} specified via ${_t} ('$ENV{${_t}}').\n"
        "BLIS: *** A working ${_d} is required. Please set ${_t}\n"
        "BLIS: *** to a ${_d} that exists (or unset ${_t}).")
    endif()
    set(${_v} "${_blis_env_${_t}}" CACHE FILEPATH "${_t} from the environment")
    set(BLIS_${_t}_CMD "$ENV{${_t}}" CACHE INTERNAL "raw ${_t} command from the environment")
  elseif(DEFINED BLIS_${_t}_CMD AND NOT _blis_help STREQUAL "${_t} from the environment")
    # An explicit -D value now selects the program; its seeded arguments do not apply.
    unset(BLIS_${_t}_CMD CACHE)
  endif()
endforeach()
# Arguments of AR and RANLIB go into every archive rule (CMake's default rules
# take the program only); the rules must exist before project() loads the languages.
foreach(_t _k IN ZIP_LISTS _blis_envs _blis_vars)
  if(_t STREQUAL "PYTHON")
    continue()
  endif()
  separate_arguments(_blis_words UNIX_COMMAND "${BLIS_${_t}_CMD}")
  list(POP_FRONT _blis_words)
  string(JOIN " " _blis_args ${_blis_words})
  if(NOT "${_blis_args}" STREQUAL "")
    foreach(_l C CXX)
      if(_t STREQUAL "AR")
        set(CMAKE_${_l}_ARCHIVE_CREATE "<CMAKE_AR> ${_blis_args} qc <TARGET> <LINK_FLAGS> <OBJECTS>")
        set(CMAKE_${_l}_ARCHIVE_APPEND "<CMAKE_AR> ${_blis_args} q <TARGET> <LINK_FLAGS> <OBJECTS>")
      else()
        set(CMAKE_${_l}_ARCHIVE_FINISH "<CMAKE_RANLIB> ${_blis_args} <TARGET>")
      endif()
    endforeach()
  endif()
endforeach()
separate_arguments(BLIS_PYTHON_ARGS UNIX_COMMAND "${BLIS_PYTHON_CMD}")
list(POP_FRONT BLIS_PYTHON_ARGS)

project(blis LANGUAGES C DESCRIPTION "BLAS-like Library Instantiation Software")
if(PROJECT_BINARY_DIR STREQUAL PROJECT_SOURCE_DIR)
  message(FATAL_ERROR
    "BLIS: in-source builds are not supported; use -B <builddir> (out-of-source)")
endif()
if(PROJECT_BINARY_DIR STREQUAL "${PROJECT_SOURCE_DIR}/build")
  message(FATAL_ERROR
    "BLIS: <source>/build is BLIS's own helper directory and cannot be a "
    "CMake binary dir: the monolithic-header generator would resolve "
    "\"cblas.h\" against the helper stub build/cblas.h there. "
    "Use a different build directory name (e.g. -B _build).")
endif()
set(BLIS_SOURCE_DIR "${PROJECT_SOURCE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(GNUInstallDirs)
include(BlisVersion)
include(BlisDetectCompiler)
include(BlisAutoDetect)
include(BlisRegistry)
include(BlisOptions)
include(BlisFlags)
include(BlisSources)

find_package(Python3 COMPONENTS Interpreter)

# ------------------------------------------------------------------------------
# Configuration selection (config_registry expansion + blacklists + autodetect)
# ------------------------------------------------------------------------------
blis_registry_parse()

if(BLIS_CONFIG STREQUAL "auto")
  blis_autodetect(_auto_cfg)
  if(_auto_cfg STREQUAL "generic")
    message(WARNING
      "BLIS: unable to detect hardware; falling back to the fully generic "
      "configuration. Performance will be poor; run with -DBLIS_CONFIG=<name> "
      "to select a specific architecture.")
  endif()
  set(BLIS_CONFIG "${_auto_cfg}" CACHE STRING "resolved" FORCE)
endif()

# Expand the family, apply the toolchain blacklist, recompute kernels from the
# surviving subconfigs.
blis_registry_expand("${BLIS_CONFIG}" _cands _k)
if(NOT _cands)
  message(FATAL_ERROR "BLIS: every subconfig of '${BLIS_CONFIG}' was blacklisted")
endif()

blis_compute_blacklist(_blacklist)
set(BLIS_CONFIG_LIST "")
foreach(c ${_cands})
  if(c IN_LIST _blacklist)
    message(STATUS "BLIS: subconfig '${c}' blacklisted for this toolchain/OS")
    continue()
  endif()
  list(APPEND BLIS_CONFIG_LIST "${c}")
endforeach()
if(NOT BLIS_CONFIG_LIST)
  message(FATAL_ERROR
    "BLIS: all subconfigs of '${BLIS_CONFIG}' are blacklisted for this toolchain")
endif()
# A singleton selection may not be blacklisted (configure fails the same way).
list(LENGTH _cands _n_cands)
list(LENGTH BLIS_CONFIG_LIST _n_final)

# KERNEL_LIST is the fixpoint of the configured name's kernel list, like
# configure's kernel_list (kernel_registry[config_name]); a rebuild from the
# per-subconfig sets reorders words.
set(BLIS_KERNEL_LIST "${BLIS_REG_KERNELS_${BLIS_CONFIG}}")
set(BLIS_CONFIG_NAME "${BLIS_CONFIG}")

# Sanity: every selected subconfig dir + kernel-set dir exists.
foreach(c ${BLIS_CONFIG_LIST})
  if(NOT IS_DIRECTORY "${BLIS_SOURCE_DIR}/config/${c}")
    message(FATAL_ERROR "BLIS: config/${c} does not exist")
  endif()
endforeach()
foreach(k ${BLIS_KERNEL_LIST})
  if(NOT IS_DIRECTORY "${BLIS_SOURCE_DIR}/kernels/${k}")
    message(FATAL_ERROR "BLIS: kernels/${k} does not exist")
  endif()
endforeach()

blis_kconfig_compute("${BLIS_CONFIG_LIST}")

if(BLIS_ENABLE_AMD_FRAME_TWEAKS AND NOT BLIS_CONFIG_NAME MATCHES "zen|amd64")
  message(STATUS "BLIS: AMD frame tweaks requested but config is not zen/amd64; disabling")
  set(BLIS_ENABLE_AMD_FRAME_TWEAKS OFF)
endif()

# CONFIG_LIST_FAM = sorted, deduped CONFIG_LIST + CONFIG_NAME (make's sort()).
set(BLIS_CONFIG_LIST_FAM ${BLIS_CONFIG_LIST} ${BLIS_CONFIG_NAME})
list(SORT BLIS_CONFIG_LIST_FAM)
list(REMOVE_DUPLICATES BLIS_CONFIG_LIST_FAM)

# ------------------------------------------------------------------------------
# bli_config.h / bli_addon.h generation (build/bli_config.h.in, bli_addon.h.in)
# ------------------------------------------------------------------------------
string(TOUPPER "${BLIS_CONFIG_NAME}" _cn_upper)
set(config_name_define "#define BLIS_FAMILY_${_cn_upper}\n")
set(config_list_defines "")
foreach(c ${BLIS_CONFIG_LIST})
  string(TOUPPER "${c}" CU)
  string(APPEND config_list_defines "#define BLIS_CONFIG_${CU}\n")
endforeach()
set(kernel_list_defines "")
foreach(k ${BLIS_KERNEL_LIST})
  string(TOUPPER "${k}" KU)
  string(APPEND kernel_list_defines "#define BLIS_KERNELS_${KU}\n")
endforeach()

# Template anchors bound by BlisVersion/BlisOptions:
set(version "${BLIS_VERSION}")
set(version_major "${BLIS_VERSION_MAJOR}")
set(version_minor "${BLIS_VERSION_MINOR}")
set(version_revision "${BLIS_VERSION_REVISION}")

_blis_probe_omp_simd(_omp_simd_ok)
if(_omp_simd_ok)
  set(enable_pragma_omp_simd 1)
  set(BLIS_PRAGMA_OMP_SIMD yes)
else()
  set(enable_pragma_omp_simd 0)
  set(BLIS_PRAGMA_OMP_SIMD no)
endif()
if(BLIS_PRAGMA_OMP_SIMD AND NOT BLIS_CC_VENDOR MATCHES "gcc|clang|icc")
  set(enable_pragma_omp_simd 0)
endif()

configure_file("${BLIS_SOURCE_DIR}/build/bli_config.h.in"
               "${PROJECT_BINARY_DIR}/bli_config.h" @ONLY)
configure_file("${BLIS_SOURCE_DIR}/build/bli_addon.h.in"
               "${PROJECT_BINARY_DIR}/bli_addon.h" @ONLY)

# ------------------------------------------------------------------------------
# Flag scaffolding (mirrors common.mk)
# ------------------------------------------------------------------------------
# NOTE: the make-based system's CFLAGS/CXXFLAGS "preset" (env captured at
# configure time) maps to CMAKE_C_FLAGS/CMAKE_CXX_FLAGS in the CMake build;
# CMake seeds them from the same environment variables at first configure
# and applies them to every compile line, ahead of target options (same
# position in the flag chain as the preset). They are intentionally NOT
# appended again by BlisFlags.
set(BLIS_CFLAGS_PRESET "")
set(BLIS_CXXFLAGS_PRESET "")
separate_arguments(BLIS_LDFLAGS_PRESET  UNIX_COMMAND "$ENV{LDFLAGS}")

set(BLIS_GLOBAL_CPPFLAGS "-D_POSIX_C_SOURCE=200112L")
if(APPLE)
  list(APPEND BLIS_GLOBAL_CPPFLAGS "-D_DARWIN_C_SOURCE")
endif()

set(BLIS_GLOBAL_CWARNFLAGS "")
if(NOT BLIS_CC_VENDOR STREQUAL "ibm")
  list(APPEND BLIS_GLOBAL_CWARNFLAGS -Werror=implicit-function-declaration)
endif()
if(NOT BLIS_CC_VENDOR STREQUAL "ibm")
  if(NOT BLIS_CC_VENDOR STREQUAL "NVIDIA")
    list(APPEND BLIS_GLOBAL_CWARNFLAGS -Wall -Wno-unused-function -Wfatal-errors -Werror=pointer-arith)
  else()
    list(APPEND BLIS_GLOBAL_CWARNFLAGS -Wall -Wno-unused-function)
  endif()
endif()
if(BLIS_CC_VENDOR MATCHES "clang|aocc")
  list(APPEND BLIS_GLOBAL_CWARNFLAGS -Wno-tautological-compare -Wno-pass-failed)
endif()
if(BLIS_CC_VENDOR STREQUAL "NVIDIA")
  list(APPEND BLIS_GLOBAL_CWARNFLAGS
    --diag_suppress unsigned_compare_with_zero
    --diag_suppress cast_to_qualified_type
    --diag_suppress bad_initializer_type
    --diag_suppress used_before_set
    --diag_suppress mixed_enum_type
    --diag_suppress incompatible_assignment_operands)
endif()
if(BLIS_CC_VENDOR STREQUAL "gcc")
  list(APPEND BLIS_GLOBAL_CWARNFLAGS -Wno-comment)
endif()

set(BLIS_CTHREADFLAGS "")
if("openmp" IN_LIST BLIS_THREADING_MODELS)
  list(APPEND BLIS_CTHREADFLAGS -fopenmp)
  # Consumers of a statically-linked openmp BLIS still need the openmp
  # runtime for the compiler they are built with (make exposes this via its
  # own -fopenmp; exported package gets the proper imported target).
  find_package(OpenMP REQUIRED COMPONENTS C)
endif()
if("pthreads" IN_LIST BLIS_THREADING_MODELS)
  list(APPEND BLIS_CTHREADFLAGS -pthread)
endif()
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads)

set(BLIS_ASANFLAGS "")
if(BLIS_ENABLE_ASAN)
  set(BLIS_ASANFLAGS -fsanitize=address)
endif()

set(BLIS_COMPSIMDFLAGS "")
if(enable_pragma_omp_simd)
  if(BLIS_CC_VENDOR STREQUAL "icc")
    set(BLIS_COMPSIMDFLAGS -qopenmp-simd)
  else()
    set(BLIS_COMPSIMDFLAGS -fopenmp-simd)
  endif()
endif()

# Symbol-visibility flags (common.mk BUILD_SYMFLAGS table).
set(BLIS_SYMFLAGS "")
if(BLIS_ENABLE_SHARED)
  if(BLIS_CC_VENDOR STREQUAL "gcc" OR BLIS_CC_VENDOR STREQUAL "icc")
    if(WIN32)
      # handled at link time via --export-all-symbols/--exclude-all-symbols
    elseif(BLIS_EXPORT_SHARED STREQUAL "all")
      set(BLIS_SYMFLAGS -fvisibility=default)
    else()
      set(BLIS_SYMFLAGS -fvisibility=hidden)
    endif()
  elseif(BLIS_CC_VENDOR MATCHES "clang|aocc")
    if(NOT WIN32)
      if(BLIS_EXPORT_SHARED STREQUAL "all")
        set(BLIS_SYMFLAGS -fvisibility=default)
      else()
        set(BLIS_SYMFLAGS -fvisibility=hidden)
      endif()
    endif()
  endif()
endif()

# Load per-config defs (family members in sorted order, like CONFIG_LIST_FAM),
# then apply the global appends.
foreach(c ${BLIS_CONFIG_LIST_FAM})
  blis_load_config_defs(${c})
  blis_finalize_config_defs(${c})
endforeach()

# Link libraries: LDFLAGS_PRESET -lm -lpthread [-lmemkind] [-lrt] [asan]
# [threading flags] plus per-config additions (rv: -latomic, bgq: SPI libs).
# Two lists grow in step. BLIS_PC_LIBS holds the flags exactly as make writes
# them (blis.pc, exported package). BLIS_LINK_LIBS holds the items CMake links
# with: its own targets (Threads::Threads), -pthread for the model dependency,
# and a flag pair such as "-framework X" joined into one item at the end.
# Preset and HPX flags go into both lists unchanged.
set(BLIS_LINK_LIBS "")
set(BLIS_PC_LIBS "")
macro(blis_add_link _cmake _pc)
  list(APPEND BLIS_LINK_LIBS ${_cmake})
  list(APPEND BLIS_PC_LIBS ${_pc})
endmacro()
blis_add_link("${BLIS_LDFLAGS_PRESET}" "${BLIS_LDFLAGS_PRESET}")
if(NOT MSVC)
  blis_add_link(m -lm)
endif()
# -lpthread: unconditional (pthread_once) unless --disable-system.
set(_blis_libpthread FALSE)
if(BLIS_ENABLE_SYSTEM)
  if(BLIS_CC_VENDOR STREQUAL "icc")
    list(REMOVE_ITEM BLIS_LINK_LIBS m -lm)
    list(REMOVE_ITEM BLIS_PC_LIBS -lm)
  endif()
  if(NOT (WIN32 AND BLIS_CC_VENDOR MATCHES "clang|aocc") AND NOT MSVC)
    set(_blis_libpthread TRUE)
    blis_add_link(Threads::Threads -lpthread)
  endif()
endif()
if(enable_memkind AND NOT BLIS_DEBUG_TYPE STREQUAL "sde")
  blis_add_link(-lmemkind -lmemkind)
endif()
if(BLIS_ENABLE_ASAN)
  blis_add_link(-fsanitize=address -fsanitize=address)
endif()
if("openmp" IN_LIST BLIS_THREADING_MODELS)
  blis_add_link(-fopenmp -fopenmp)
endif()
if("pthreads" IN_LIST BLIS_THREADING_MODELS)
  # common.mk adds LIBPTHREAD (empty without system support) to blis.pc.
  blis_add_link(-pthread "")
  if(_blis_libpthread)
    list(APPEND BLIS_PC_LIBS -lpthread)
  endif()
endif()
foreach(c ${BLIS_CONFIG_LIST_FAM})
  if(BLIS_DEFS_LDFLAGS_${c})
    separate_arguments(_cfg_ld UNIX_COMMAND "${BLIS_DEFS_LDFLAGS_${c}}")
    blis_add_link("${_cfg_ld}" "${_cfg_ld}")
  endif()
endforeach()

# HPX threading: pkg-config based, requires C++.
if("hpx" IN_LIST BLIS_THREADING_MODELS)
  enable_language(CXX)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(HPX REQUIRED hpx_component)
  set(BLIS_CXXLANGFLAGS -std=c++17)
  # common.mk: LDFLAGS += pkg-config --libs minus -shared (raw flags, no target
  # name, so blis.pc and the exported target carry real linker options).
  set(_hpx_ld ${HPX_LDFLAGS})
  list(FILTER _hpx_ld EXCLUDE REGEX "^-shared$")
  blis_add_link("${_hpx_ld}" "${_hpx_ld}")
  if(APPLE)
    foreach(_f ${_hpx_ld})
      if(_f MATCHES "^-L(.+)")
        blis_add_link("-Wl,-rpath,${CMAKE_MATCH_1}" "-Wl,-rpath,${CMAKE_MATCH_1}")
      endif()
    endforeach()
  endif()
  # common.mk: CTHREADFLAGS += HPX cflags minus -std=*, used for C and C++.
  set(_hpx_cf ${HPX_CFLAGS_OTHER})
  list(FILTER _hpx_cf EXCLUDE REGEX "^-std=")
  list(APPEND BLIS_CTHREADFLAGS ${_hpx_cf})
else()
  set(BLIS_CXXLANGFLAGS -std=c++11)
endif()

if(UNIX AND NOT APPLE)
  # common.mk appends -lrt last (after the threading and HPX flags), except on Android/Bionic.
  include(CheckCSourceCompiles)
  check_c_source_compiles("#ifndef __BIONIC__\n#error not bionic\n#endif\nint main(void){return 0;}" BLIS_ON_BIONIC)
  if(NOT BLIS_ON_BIONIC)
    blis_add_link(rt -lrt)
  endif()
endif()

# CMake links an item as given: "-framework X" is one item, not two, or the
# second word becomes -lX. blis.pc keeps the two words (BLIS_PC_LIBS).
set(_blis_joined "")
set(_blis_pend "")
foreach(_l ${BLIS_LINK_LIBS})
  if(_blis_pend)
    list(APPEND _blis_joined "${_blis_pend} ${_l}")
    set(_blis_pend "")
  elseif(_l MATCHES "^-(weak_|needed_|reexport_)?framework$")
    set(_blis_pend "${_l}")
  else()
    list(APPEND _blis_joined "${_l}")
  endif()
endforeach()
if(_blis_pend)
  list(APPEND _blis_joined "${_blis_pend}")
endif()
set(BLIS_LINK_LIBS "")
set(BLIS_LINK_OPTS "")
foreach(_l ${_blis_joined})
  # target_link_libraries rejects any item with "::" that names no target
  # (CMP0028), so a flag such as -Wl,-rpath,a::b goes through target_link_options.
  if(_l MATCHES "^[-/].*::")
    list(APPEND BLIS_LINK_OPTS "${_l}")
  else()
    list(APPEND BLIS_LINK_LIBS "${_l}")
  endif()
endforeach()

# ------------------------------------------------------------------------------
# Source collection
# ------------------------------------------------------------------------------
# Frame sources (C; compat subtrees filtered per BLAS/CBLAS; *_amd twins per
# BLIS_ENABLE_AMD_FRAME_TWEAKS).
set(_frame_suffixes c)
if("hpx" IN_LIST BLIS_THREADING_MODELS)
  list(APPEND _frame_suffixes cpp)
endif()
blis_collect(FRAME_SRC "${BLIS_SOURCE_DIR}/frame" ${_frame_suffixes})
if(NOT BLIS_EFFECTIVE_BLAS)
  list(FILTER FRAME_SRC EXCLUDE REGEX "/compat/")
elseif(NOT BLIS_ENABLE_CBLAS)
  list(FILTER FRAME_SRC EXCLUDE REGEX "/compat/cblas/")
endif()

list(FILTER FRAME_SRC EXCLUDE REGEX "/frame/include/")
file(GLOB_RECURSE _amd_twins_all CONFIGURE_DEPENDS "${BLIS_SOURCE_DIR}/frame/*_amd.c")
foreach(f ${_amd_twins_all})
  if(BLIS_ENABLE_AMD_FRAME_TWEAKS)
    string(REGEX REPLACE "_amd\\.c$" ".c" base "${f}")
    list(FIND FRAME_SRC "${base}" _bi)
    if(_bi GREATER -1)
      list(REMOVE_AT FRAME_SRC ${_bi})
    endif()
  else()
    list(FIND FRAME_SRC "${f}" _ai)
    if(_ai GREATER -1)
      list(REMOVE_AT FRAME_SRC ${_ai})
    endif()
  endif()
endforeach()

# Reference kernels: bli_cntx_ref.c (refinit class) vs everything else.
blis_collect(REFKERN_ALL "${BLIS_SOURCE_DIR}/ref_kernels" c)
set(REFINIT_SRC "")
set(REFKERN_SRC "")
foreach(f ${REFKERN_ALL})
  if(f MATCHES "/bli_cntx_ref\\.c$")
    list(APPEND REFINIT_SRC "${f}")
  else()
    list(APPEND REFKERN_SRC "${f}")
  endif()
endforeach()

# Config / kernel sources per config among CONFIG_LIST_FAM (the family dir
# itself usually holds only headers, but make fragments it too).
foreach(c ${BLIS_CONFIG_LIST_FAM})
  blis_collect(CONFIG_SRC_${c} "${BLIS_SOURCE_DIR}/config/${c}" c)
endforeach()
foreach(k ${BLIS_KERNEL_LIST})
  blis_collect(KERNEL_SRC_${k} "${BLIS_SOURCE_DIR}/kernels/${k}" c s S)
endforeach()

# Addons and sandbox.
foreach(a ${BLIS_ENABLE_ADDONS})
  blis_collect(ADDON_ALL_${a} "${BLIS_SOURCE_DIR}/addon/${a}" c cc cpp cxx)
  set(ADDON_SRC_${a} "")
  set(ADDON_KERNEL_SRC_${a} "")
  foreach(f ${ADDON_ALL_${a}})
    if(f MATCHES "/kernels/")
      list(APPEND ADDON_KERNEL_SRC_${a} "${f}")
    else()
      list(APPEND ADDON_SRC_${a} "${f}")
    endif()
  endforeach()
endforeach()
if(BLIS_SANDBOX)
  blis_collect(SANDBOX_SRC "${BLIS_SOURCE_DIR}/sandbox/${BLIS_SANDBOX}" c cc cpp cxx)
endif()

# C++ sources present? (addons/sandbox/hpx)
set(_need_cxx FALSE)
if("hpx" IN_LIST BLIS_THREADING_MODELS)
  set(_need_cxx TRUE)
endif()
foreach(a ${BLIS_ENABLE_ADDONS})
  foreach(f ${ADDON_ALL_${a}})
    if(f MATCHES "\\.(cc|cpp|cxx)$")
      set(_need_cxx TRUE)
    endif()
  endforeach()
endforeach()
if(BLIS_SANDBOX)
  foreach(f ${SANDBOX_SRC})
    if(f MATCHES "\\.(cc|cpp|cxx)$")
      set(_need_cxx TRUE)
    endif()
  endforeach()
endif()
if(_need_cxx)
  enable_language(CXX)
endif()

# ------------------------------------------------------------------------------
# Flattened monolithic header (build/flatten-headers.py)
# ------------------------------------------------------------------------------
blis_header_dirs(FLAT_HEADER_DIRS
  "${BLIS_SOURCE_DIR}/frame" "${BLIS_SOURCE_DIR}/ref_kernels")
foreach(c ${BLIS_CONFIG_LIST_FAM})
  blis_header_dirs(_hdirs "${BLIS_SOURCE_DIR}/config/${c}")
  list(APPEND FLAT_HEADER_DIRS ${_hdirs})
endforeach()
foreach(k ${BLIS_KERNEL_LIST})
  blis_header_dirs(_hdirs "${BLIS_SOURCE_DIR}/kernels/${k}")
  list(APPEND FLAT_HEADER_DIRS ${_hdirs})
endforeach()
foreach(a ${BLIS_ENABLE_ADDONS})
  blis_header_dirs(_hdirs "${BLIS_SOURCE_DIR}/addon/${a}")
  list(APPEND FLAT_HEADER_DIRS ${_hdirs})
endforeach()
if(BLIS_SANDBOX)
  blis_header_dirs(_hdirs "${BLIS_SOURCE_DIR}/sandbox/${BLIS_SANDBOX}")
  list(APPEND FLAT_HEADER_DIRS ${_hdirs})
endif()
# The build directory comes first (it holds the generated bli_config.h and
# bli_addon.h, like '.' in the make-time in-tree build).
list(PREPEND FLAT_HEADER_DIRS "${PROJECT_BINARY_DIR}")
list(REMOVE_DUPLICATES FLAT_HEADER_DIRS)
string(REPLACE ";" " " FLAT_HEADER_DIRS_STR "${FLAT_HEADER_DIRS}")

# All source headers participate as dependencies.
blis_collect(ALL_HEADERS "${BLIS_SOURCE_DIR}/frame" h)
blis_collect(_h1 "${BLIS_SOURCE_DIR}/ref_kernels" h)
list(APPEND ALL_HEADERS ${_h1})
foreach(c ${BLIS_CONFIG_LIST_FAM})
  blis_collect(_h1 "${BLIS_SOURCE_DIR}/config/${c}" h)
  list(APPEND ALL_HEADERS ${_h1})
endforeach()
foreach(k ${BLIS_KERNEL_LIST})
  blis_collect(_h1 "${BLIS_SOURCE_DIR}/kernels/${k}" h)
  list(APPEND ALL_HEADERS ${_h1})
endforeach()
foreach(a ${BLIS_ENABLE_ADDONS})
  blis_collect(_h1 "${BLIS_SOURCE_DIR}/addon/${a}" h hh hpp hxx)
  list(APPEND ALL_HEADERS ${_h1})
endforeach()
if(BLIS_SANDBOX)
  blis_collect(_h1 "${BLIS_SOURCE_DIR}/sandbox/${BLIS_SANDBOX}" h hh hpp hxx)
  list(APPEND ALL_HEADERS ${_h1})
endif()

if(NOT Python3_Interpreter_FOUND)
  message(FATAL_ERROR "BLIS: python3 is required (build/flatten-headers.py)")
endif()

# Keep the paths recorded in #line directives relative to the build dir
# (like the make-based build), instead of leaking absolute build paths.
set(_flat_in "${BLIS_SOURCE_DIR}/frame/include/blis.h")
file(RELATIVE_PATH _flat_in_rel "${PROJECT_BINARY_DIR}" "${_flat_in}")
set(_flat_dirs_rel "")
foreach(d ${FLAT_HEADER_DIRS})
  file(RELATIVE_PATH _r "${PROJECT_BINARY_DIR}" "${d}")
  if(_r STREQUAL "")
    set(_r ".")
  endif()
  list(APPEND _flat_dirs_rel "${_r}")
endforeach()
string(REPLACE ";" " " FLAT_HEADER_DIRS_STR "${_flat_dirs_rel}")

file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/include")
add_custom_command(
  OUTPUT "${PROJECT_BINARY_DIR}/include/blis.h"
  COMMAND ${Python3_EXECUTABLE} ${BLIS_PYTHON_ARGS} "${BLIS_SOURCE_DIR}/build/flatten-headers.py"
          -l -v1 "${_flat_in_rel}"
          "include/blis.h" "include"
          "${FLAT_HEADER_DIRS_STR}"
  WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
  DEPENDS ${ALL_HEADERS}
          "${BLIS_SOURCE_DIR}/build/flatten-headers.py"
          "${PROJECT_BINARY_DIR}/bli_config.h" "${PROJECT_BINARY_DIR}/bli_addon.h"
  COMMENT "Flattening monolithic header blis.h")

set(_flat_outputs "${PROJECT_BINARY_DIR}/include/blis.h")
if(BLIS_ENABLE_CBLAS)
  file(RELATIVE_PATH _cblas_in_rel "${PROJECT_BINARY_DIR}" "${BLIS_SOURCE_DIR}/frame/compat/cblas/src/cblas.h")
  add_custom_command(
    OUTPUT "${PROJECT_BINARY_DIR}/include/cblas.h"
    COMMAND ${Python3_EXECUTABLE} ${BLIS_PYTHON_ARGS} "${BLIS_SOURCE_DIR}/build/flatten-headers.py"
            -l -v1 "${_cblas_in_rel}"
            "include/cblas.h" "include"
            "${FLAT_HEADER_DIRS_STR}"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
    DEPENDS ${ALL_HEADERS} "${PROJECT_BINARY_DIR}/include/blis.h"
            "${BLIS_SOURCE_DIR}/build/flatten-headers.py"
    COMMENT "Flattening monolithic header cblas.h")
  list(APPEND _flat_outputs "${PROJECT_BINARY_DIR}/include/cblas.h")
endif()
add_custom_target(blis_flat_headers DEPENDS ${_flat_outputs})

# Include dirs shared by all library objects: the flat-header dir, the dirs of
# headers included by ref_kernels/bli_cntx_ref.c, and frame/include (+cblas).
file(STRINGS "${BLIS_SOURCE_DIR}/ref_kernels/bli_cntx_ref.c" _ref_inc
     REGEX "^[ \t]*#[ \t]*include")
set(BLIS_CINCDIRS "")
foreach(l ${_ref_inc})
  string(REGEX MATCH "[\"<]([a-zA-Z0-9_./-]+)[\">]" _m "${l}")
  if(CMAKE_MATCH_1 AND NOT CMAKE_MATCH_1 STREQUAL "blis.h")
    foreach(hf ${ALL_HEADERS})
      if(hf MATCHES "/${CMAKE_MATCH_1}$")
        get_filename_component(_d "${hf}" DIRECTORY)
        list(APPEND BLIS_CINCDIRS "${_d}")
      endif()
    endforeach()
  endif()
endforeach()
list(APPEND BLIS_CINCDIRS "${BLIS_SOURCE_DIR}/frame/include")
if(BLIS_ENABLE_CBLAS)
  list(APPEND BLIS_CINCDIRS "${BLIS_SOURCE_DIR}/frame/compat/cblas/src")
endif()
if("hpx" IN_LIST BLIS_THREADING_MODELS)
  list(APPEND BLIS_CINCDIRS ${HPX_INCLUDE_DIRS})
endif()
list(REMOVE_DUPLICATES BLIS_CINCDIRS)

# ------------------------------------------------------------------------------
# Object libraries
# ------------------------------------------------------------------------------
blis_add_objects(blis_obj_frame CONFIG ${BLIS_CONFIG_NAME} CLASS frame
                 SOURCES ${FRAME_SRC})

foreach(c ${BLIS_CONFIG_LIST_FAM})
  blis_add_objects(blis_obj_config_${c} CONFIG ${c} CLASS config
                   SOURCES ${CONFIG_SRC_${c}})
endforeach()
foreach(c ${BLIS_CONFIG_LIST})
  blis_add_objects(blis_obj_refinit_${c} CONFIG ${c} CLASS refinit
                   SOURCES ${REFINIT_SRC})
  blis_add_objects(blis_obj_refkern_${c} CONFIG ${c} CLASS refkern
                   SOURCES ${REFKERN_SRC})
endforeach()

foreach(k ${BLIS_KERNEL_LIST})
  blis_kconfig_for(${k} _kc)
  blis_add_objects(blis_obj_kern_${k} CONFIG ${_kc} CLASS kernel
                   SOURCES ${KERNEL_SRC_${k}})
endforeach()

set(ADDON_INCDIRS "")
foreach(a ${BLIS_ENABLE_ADDONS})
  blis_header_dirs(_ai "${BLIS_SOURCE_DIR}/addon/${a}")
  list(APPEND ADDON_INCDIRS ${_ai})
  blis_add_objects(blis_obj_addon_${a} CONFIG ${BLIS_CONFIG_NAME} CLASS addon
                   SOURCES ${ADDON_SRC_${a}} EXTRA_INCLUDES ${ADDON_INCDIRS})
  blis_add_objects(blis_obj_addonkern_${a} CONFIG ${BLIS_CONFIG_NAME} CLASS addon-kernel
                   SOURCES ${ADDON_KERNEL_SRC_${a}} EXTRA_INCLUDES ${ADDON_INCDIRS})
endforeach()

if(BLIS_SANDBOX)
  blis_header_dirs(SANDBOX_INCDIRS "${BLIS_SOURCE_DIR}/sandbox/${BLIS_SANDBOX}")
  blis_add_objects(blis_obj_sandbox CONFIG ${BLIS_CONFIG_NAME} CLASS sandbox
                   SOURCES ${SANDBOX_SRC} EXTRA_INCLUDES ${SANDBOX_INCDIRS})
endif()

# ------------------------------------------------------------------------------
# Libraries
# ------------------------------------------------------------------------------
get_property(_objlibs GLOBAL PROPERTY BLIS_OBJLIBS)
set(_obj_exprs "")
foreach(o ${_objlibs})
  list(APPEND _obj_exprs $<TARGET_OBJECTS:${o}>)
endforeach()

if(BLIS_ENABLE_STATIC)
  add_library(blis_static STATIC ${_obj_exprs})
  set_target_properties(blis_static PROPERTIES
    OUTPUT_NAME blis PREFIX "lib"
    ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
  target_link_libraries(blis_static PUBLIC ${BLIS_LINK_LIBS})
  target_link_options(blis_static PUBLIC ${BLIS_LINK_OPTS})
  if("openmp" IN_LIST BLIS_THREADING_MODELS)
    target_link_libraries(blis_static PUBLIC OpenMP::OpenMP_C)
  endif()
  target_include_directories(blis_static INTERFACE
    $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/blis>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
endif()

if(BLIS_ENABLE_SHARED)
  add_library(blis_shared SHARED ${_obj_exprs})
  set_target_properties(blis_shared PROPERTIES
    OUTPUT_NAME blis PREFIX "lib"
    LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib"
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib"
    VERSION "${BLIS_SO_MMB}" SOVERSION "${BLIS_SO_MAJOR}")
  if(APPLE AND NOT BLIS_DARWIN_RPATH)
    set_target_properties(blis_shared PROPERTIES
      INSTALL_NAME_DIR "${BLIS_INSTALL_FULL_LIBDIR}")
  endif()
  if(WIN32)
    # Match the make-based naming: libblis.<so-major>.dll (+ import lib).
    set_target_properties(blis_shared PROPERTIES
      RUNTIME_OUTPUT_NAME "libblis.${BLIS_SO_MAJOR}" PREFIX "")
  endif()
  target_link_libraries(blis_shared PRIVATE ${BLIS_LINK_LIBS})
  # In-tree consumers link BLIS_LINK_OPTS like make's LDFLAGS; the export does not carry them.
  target_link_options(blis_shared PRIVATE ${BLIS_LINK_OPTS})
  target_link_options(blis_shared INTERFACE "$<BUILD_INTERFACE:${BLIS_LINK_OPTS}>")
  if(WIN32 AND NOT MSVC AND BLIS_CC_VENDOR MATCHES "^(gcc|clang|aocc)$")
    # MinGW/ld.bfd export control (make's SOFLAGS table).
    if(BLIS_EXPORT_SHARED STREQUAL "all")
      target_link_options(blis_shared PRIVATE
        -Wl,--export-all-symbols -Wl,--enable-auto-import)
    else()
      target_link_options(blis_shared PRIVATE -Wl,--exclude-all-symbols)
    endif()
  endif()
  if(NOT MSVC)
    # blis.h's static inline helpers call libm (pow, floor, ...); consumers
    # of the shared library still need -lm for their own translation units.
    target_link_libraries(blis_shared INTERFACE m)
  endif()
  target_include_directories(blis_shared INTERFACE
    $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/blis>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
endif()

# In-tree consumers (testsuite, blastest, examples): link static when
# available; on Windows the make build uses the dll regardless.
if(BLIS_ENABLE_STATIC AND NOT (WIN32 AND BLIS_ENABLE_SHARED))
  set(BLIS_LINK_TARGET blis_static)
else()
  set(BLIS_LINK_TARGET blis_shared)
endif()
add_library(blis::blis ALIAS ${BLIS_LINK_TARGET})

# ------------------------------------------------------------------------------
# Install + packaging
# ------------------------------------------------------------------------------
if(BLIS_ENABLE_STATIC)
  set(_export_name_static "blis-static")
  if(NOT BLIS_ENABLE_SHARED)
    set(_export_name_static "blis")
  endif()
  set_target_properties(blis_static PROPERTIES EXPORT_NAME ${_export_name_static})
  install(TARGETS blis_static EXPORT blisTargets
    ARCHIVE DESTINATION ${BLIS_INSTALL_LIBDIR} COMPONENT libs)
endif()
if(BLIS_ENABLE_SHARED)
  set_target_properties(blis_shared PROPERTIES EXPORT_NAME blis)
  # make's install-libs copies only the versioned file; install-lib-symlinks
  # adds the two links on top of it. The TARGETS rule (file plus links) is the
  # lib-symlinks component, so the versioned file also gets its own rule.
  install(TARGETS blis_shared EXPORT blisTargets
    LIBRARY DESTINATION ${BLIS_INSTALL_LIBDIR} COMPONENT lib-symlinks
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT libs)
  if(NOT WIN32)
    install(FILES $<TARGET_FILE:blis_shared>
      DESTINATION ${BLIS_INSTALL_LIBDIR} COMPONENT libs
      PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE
                  WORLD_READ WORLD_EXECUTE)
  endif()
endif()

# Generated monolithic headers + one-level-up helper headers.
install(FILES "${PROJECT_BINARY_DIR}/include/blis.h"
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/blis COMPONENT headers)
install(FILES "${BLIS_SOURCE_DIR}/build/blis.h"
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} COMPONENT helper-headers)
if(BLIS_ENABLE_CBLAS)
  install(FILES "${PROJECT_BINARY_DIR}/include/cblas.h"
          DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/blis COMPONENT headers)
  install(FILES "${BLIS_SOURCE_DIR}/build/cblas.h"
          DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} COMPONENT helper-headers)
endif()

install(EXPORT blisTargets NAMESPACE blis::
        DESTINATION ${BLIS_INSTALL_LIBDIR}/cmake/blis COMPONENT cmake-package)
# An absolute package dir makes CMake write the configure-time prefix into
# blisTargets.cmake as _IMPORT_PREFIX; point it at the prefix of this install.
if(IS_ABSOLUTE "${BLIS_INSTALL_LIBDIR}")
  install(CODE "set(_blis_tgtdir \"${BLIS_INSTALL_LIBDIR}/cmake/blis\")" COMPONENT cmake-package)
  install(CODE [[
    set(_f "$ENV{DESTDIR}${_blis_tgtdir}/blisTargets.cmake")
    file(READ "${_f}" _c)
    string(REGEX REPLACE "set\\(_IMPORT_PREFIX \"[^\"]*\"\\)"
           "set(_IMPORT_PREFIX \"${CMAKE_INSTALL_PREFIX}\")" _c "${_c}")
    file(WRITE "${_f}" "${_c}")
  ]] COMPONENT cmake-package)
endif()

# Per-subconfiguration flag metadata exported for plugins (installed into
# blisConfig.cmake; consumed by BlisPluginHelpers.cmake).
set(BLISPLUGIN_EXPORTS "")
blis_get_cflags(${BLIS_CONFIG_NAME} addon _blisplugin_frame)
string(REPLACE ";" " " _blisplugin_frame_s "${_blisplugin_frame}")
string(APPEND BLISPLUGIN_EXPORTS "set(blis_FRAME_CFLAGS \"${_blisplugin_frame_s}\")\n")
foreach(c ${BLIS_CONFIG_LIST})
  blis_get_cflags(${c} kernel _kf)
  string(REPLACE ";" " " _kfs "${_kf}")
  string(APPEND BLISPLUGIN_EXPORTS "set(blis_KERNEL_CFLAGS_${c} \"${_kfs}\")\n")
  blis_get_cflags(${c} refkern _rf)
  # strip the BLIS-internal force-include/DBLIS_IN_REF_KERNEL tokens; the
  # plugin passes its own defs header via blis_plugin_refkern_flags().
  set(_rfo "")
  set(_prev "")
  foreach(t ${_rf})
    if(_prev STREQUAL "-include")
      set(_prev "")
      continue()
    endif()
    if(NOT t STREQUAL "-DBLIS_IN_REF_KERNEL=1" AND NOT t STREQUAL "-include")
      list(APPEND _rfo "${t}")
    endif()
    set(_prev "${t}")
  endforeach()
  string(REPLACE ";" " " _rfs "${_rfo}")
  string(APPEND BLISPLUGIN_EXPORTS "set(blis_REFKERN_CFLAGS_${c} \"${_rfs}\")\n")
endforeach()

include(CMakePackageConfigHelpers)
set(BLIS_NEEDS_THREADS OFF)
if(BLIS_ENABLE_SYSTEM)
  set(BLIS_NEEDS_THREADS ON)
endif()
set(BLIS_NEEDS_OPENMP OFF)
if("openmp" IN_LIST BLIS_THREADING_MODELS)
  set(BLIS_NEEDS_OPENMP ON)
endif()
set(BLIS_NEEDS_MEMKIND OFF)
if(enable_memkind)
  set(BLIS_NEEDS_MEMKIND ON)
endif()
configure_file("${BLIS_SOURCE_DIR}/cmake/blisConfig.cmake.in"
               "${PROJECT_BINARY_DIR}/blisConfig.cmake" @ONLY)
write_basic_package_version_file(
  "${PROJECT_BINARY_DIR}/blisConfigVersion.cmake"
  VERSION "${BLIS_VERSION}" COMPATIBILITY SameMajorVersion)
configure_file("${BLIS_SOURCE_DIR}/cmake/BlisPluginHelpers.cmake.in"
               "${PROJECT_BINARY_DIR}/BlisPluginHelpers.cmake" @ONLY)
install(FILES "${PROJECT_BINARY_DIR}/blisConfig.cmake"
              "${PROJECT_BINARY_DIR}/blisConfigVersion.cmake"
              "${PROJECT_BINARY_DIR}/BlisPluginHelpers.cmake"
        DESTINATION ${BLIS_INSTALL_LIBDIR}/cmake/blis COMPONENT cmake-package)

# pkg-config (template anchors @prefix@ @exec_prefix@ @libdir@ @includedir@
# @LDFLAGS@ @PACKAGE_VERSION@, as used by blis.pc.in). The four path lines get
# the expanded values make install writes; @BLIS_INSTALL_PREFIX@ is replaced at
# install time, so `cmake --install --prefix <elsewhere>` yields a .pc that
# matches the actual install.
set(prefix "@BLIS_INSTALL_PREFIX@")
if(NOT "${BLIS_INSTALL_EXEC_PREFIX}" STREQUAL "")
  set(exec_prefix "${BLIS_INSTALL_EXEC_PREFIX}")
else()
  set(exec_prefix "@BLIS_INSTALL_PREFIX@")
endif()
if(IS_ABSOLUTE "${BLIS_INSTALL_LIBDIR}")
  set(libdir "${BLIS_INSTALL_LIBDIR}")
else()
  set(libdir "@BLIS_INSTALL_PREFIX@/${BLIS_INSTALL_LIBDIR}")
endif()
if(IS_ABSOLUTE "${CMAKE_INSTALL_INCLUDEDIR}")
  set(includedir "${CMAKE_INSTALL_INCLUDEDIR}")
else()
  set(includedir "@BLIS_INSTALL_PREFIX@/${CMAKE_INSTALL_INCLUDEDIR}")
endif()
set(PACKAGE_VERSION "${BLIS_VERSION}")
# A CMake target reference (not a flag, not a path) cannot go into blis.pc.
foreach(l ${BLIS_PC_LIBS})
  if(TARGET "${l}" OR l MATCHES "^[^-/][^/]*::")
    message(FATAL_ERROR "BLIS: target name '${l}' cannot go into blis.pc")
  endif()
endforeach()
set(_pc_ldflags ${BLIS_PC_LIBS})
string(REPLACE ";" " " LDFLAGS "${_pc_ldflags}")
configure_file("${BLIS_SOURCE_DIR}/blis.pc.in"
               "${PROJECT_BINARY_DIR}/blis.pc" @ONLY)
# blis.pc is installed through file(INSTALL) so the install step replaces
# @BLIS_INSTALL_PREFIX@ with the actual prefix (same pattern as config.mk).
install(CODE "set(_blis_pcfile \"${PROJECT_BINARY_DIR}/blis.pc\")\nset(_blis_pcdir \"${BLIS_SHAREDIR}/pkgconfig\")" COMPONENT share)
install(CODE [[
  file(READ "${_blis_pcfile}" _c)
  string(REPLACE "@BLIS_INSTALL_PREFIX@" "${CMAKE_INSTALL_PREFIX}" _c "${_c}")
  file(WRITE "${_blis_pcfile}.d/blis.pc" "${_c}")
  cmake_path(ABSOLUTE_PATH _blis_pcdir BASE_DIRECTORY "${CMAKE_INSTALL_PREFIX}")
  file(INSTALL "${_blis_pcfile}.d/blis.pc" DESTINATION "${_blis_pcdir}"
       PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
]] COMPONENT share)

# Vendor C++ headers (equivalent of `make install INSTALL_HH=yes`).
option(BLIS_INSTALL_VENDOR_CPP_HEADERS
  "Additionally install AMD's C++ template headers (vendor/cpp/*.hh)" OFF)
if(BLIS_INSTALL_VENDOR_CPP_HEADERS)
  file(GLOB _vendor_hh "${BLIS_SOURCE_DIR}/vendor/cpp/*.hh")
  install(FILES ${_vendor_hh} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/blis COMPONENT headers)
endif()

# Make-build parity: share/blis fragments, showconfig, uninstall-old, partial
# install and uninstall targets.
# config.mk records the raw AR, RANLIB and PYTHON strings, as configure does;
# BlisMakeCompat reads the CMake variables, so shadow them for this include.
foreach(_t _v IN ZIP_LISTS _blis_envs _blis_vars)
  if(DEFINED BLIS_${_t}_CMD)
    set(${_v} "${BLIS_${_t}_CMD}")
  endif()
endforeach()
include(make/BlisMakeCompat)
foreach(_t _v IN ZIP_LISTS _blis_envs _blis_vars)
  if(DEFINED BLIS_${_t}_CMD)
    unset(${_v})
  endif()
endforeach()

# ------------------------------------------------------------------------------
# Tests + examples
# ------------------------------------------------------------------------------
include(CTest)
if(BUILD_TESTING)
  include(BlisTesting)
  add_subdirectory(testsuite)
  blis_register_testsuite_tests()
  # blastest drivers call lsame_/xerbla_, which may be omitted from the
  # library (lapack-compat mode): in that case those symbols must come from
  # a real LAPACK, so the bundled drivers cannot link.
  set(_blat_blocked FALSE)
  if(_omit_list MATCHES "lsame" OR _omit_list MATCHES "xerbla")
    set(_blat_blocked TRUE)
  endif()
  if(BLIS_EFFECTIVE_BLAS AND NOT _blat_blocked)
    add_subdirectory(blastest)
    blis_register_blastest_tests()
  elseif(_blat_blocked)
    message(STATUS "BLIS: blastest disabled (lsame/xerbla omitted; LAPACK-compat mode)")
  endif()

  # make check = checkblis-fast + checkblas.
  add_custom_target(check
    COMMAND ${CMAKE_CTEST_COMMAND} --test-dir "${PROJECT_BINARY_DIR}"
            $<$<BOOL:$<CONFIG>>:-C$<SEMICOLON>$<CONFIG>>
            -L "^(fast|blastest)$" --output-on-failure
    USES_TERMINAL VERBATIM COMMAND_EXPAND_LISTS)
  add_dependencies(check test_libblis.x)
  if(TARGET blastest-bin)
    add_dependencies(check blastest-bin)
  endif()
endif()

if(BLIS_BUILD_EXAMPLES)
  add_subdirectory(examples)
endif()

# Make-build parity: the check*, test*, clean* and other make target names.
include(make/BlisMakeTargets)

# Maintainer helpers: 'symbols' regenerates the MSVC export manifest
# build/libblis-symbols.def from the flattened header; 'changelog' refreshes
# the CHANGELOG file from git. (Both write into the source tree, as upstream.)
add_custom_target(symbols
  COMMAND "${CMAKE_COMMAND}"
          -DCC_BIN=${CMAKE_C_COMPILER}
          -DFLAT=${PROJECT_BINARY_DIR}/include/blis.h
          -DCFG=${BLIS_CONFIG_NAME}
          -DSCRIPT=${BLIS_SOURCE_DIR}/build/gen-libblis-symbols.sh
          -DOUT=${BLIS_SOURCE_DIR}/build/libblis-symbols.def
          -P ${BLIS_SOURCE_DIR}/cmake/BlisGenSymbols.cmake
  DEPENDS blis_flat_headers)
if(GIT_FOUND)
  add_custom_target(changelog
    COMMAND "${CMAKE_COMMAND}"
            -DGIT=${GIT_EXECUTABLE} -DSRC=${BLIS_SOURCE_DIR}
            -DOUT=${BLIS_SOURCE_DIR}/CHANGELOG
            -P ${BLIS_SOURCE_DIR}/cmake/BlisChangelog.cmake)
endif()

# ------------------------------------------------------------------------------
# Configuration summary (make showconfig equivalent)
# ------------------------------------------------------------------------------
message(STATUS "")
message(STATUS "BLIS configuration summary")
message(STATUS "  version .................. ${BLIS_VERSION} (so ${BLIS_SO_MAJOR}.${BLIS_SO_MINORB})")
message(STATUS "  configuration family ..... ${BLIS_CONFIG_NAME}")
message(STATUS "  sub-configurations ....... ${BLIS_CONFIG_LIST}")
message(STATUS "  kernel sets .............. ${BLIS_KERNEL_LIST}")
message(STATUS "  kernel-to-config map ..... ${BLIS_KCONFIG_MAP}")
message(STATUS "  threading ................ ${BLIS_THREADING_MODELS} (default: ${BLIS_THREAD_DEFAULT})")
message(STATUS "  int size / BLAS int size . ${BLIS_INT_SIZE} / ${BLIS_BLAS_INT_SIZE}")
message(STATUS "  BLAS / CBLAS ............. ${BLIS_EFFECTIVE_BLAS} / ${BLIS_ENABLE_CBLAS}")
message(STATUS "  static / shared .......... ${BLIS_ENABLE_STATIC} / ${BLIS_ENABLE_SHARED}")
message(STATUS "  export shared ............ ${BLIS_EXPORT_SHARED}")
message(STATUS "  debug type ............... ${BLIS_DEBUG_TYPE}")
message(STATUS "  addons ................... ${BLIS_ENABLE_ADDONS}")
message(STATUS "  sandbox .................. ${BLIS_SANDBOX}")
message(STATUS "  memkind .................. ${enable_memkind}")
message(STATUS "  install prefix ........... ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")

# make evaluates a make_defs.mk $(error) before every target, so a deferred
# error must stop every target here, ahead of any compile. Keep this last:
# it must see all targets.
if(TARGET blis_config_error)
  set(_dirs "${CMAKE_CURRENT_SOURCE_DIR}")
  set(_all_targets "")
  while(_dirs)
    list(POP_FRONT _dirs _d)
    get_property(_t DIRECTORY "${_d}" PROPERTY BUILDSYSTEM_TARGETS)
    list(APPEND _all_targets ${_t})
    get_property(_s DIRECTORY "${_d}" PROPERTY SUBDIRECTORIES)
    list(APPEND _dirs ${_s})
  endwhile()
  list(REMOVE_ITEM _all_targets blis_config_error)
  foreach(_t IN LISTS _all_targets)
    add_dependencies(${_t} blis_config_error)
  endforeach()
endif()
