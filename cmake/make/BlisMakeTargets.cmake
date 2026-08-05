# Make-build parity: one CMake target for each Makefile target name that has
# no CMake target of its own (check*, test*, clean*, check-env*, libs, ...).
# Included from the top-level CMakeLists.txt after the test and example dirs.
# The install-* and uninstall-* names live in other modules.

# Script mode (cmake -DDIR=<dir> -P this-file): remove the object files below
# DIR, for cleanlib and clean*test (cmake -E rm cannot glob).
if(CMAKE_SCRIPT_MODE_FILE)
  file(GLOB_RECURSE _objs "${DIR}/*.o" "${DIR}/*.obj")
  # make builds the examples outside obj/<config>, so cleanlib keeps them.
  list(FILTER _objs EXCLUDE REGEX "^${DIR}/examples/")
  if(_objs)
    file(REMOVE ${_objs})
  endif()
  return()
endif()

# A make name: depends on DEPS, then runs the optional command in ARGN. If a
# dep does not exist (BUILD_TESTING off, blastest disabled), the target fails.
function(_blis_target name deps)
  foreach(_d IN LISTS deps)
    if(NOT TARGET ${_d})
      add_custom_target(${name} VERBATIM
        COMMAND "${CMAKE_COMMAND}" -E echo
                "${name}: no target ${_d} (BUILD_TESTING off or blastest disabled)"
        COMMAND "${CMAKE_COMMAND}" -E false)
      return()
    endif()
  endforeach()
  if(ARGN)
    add_custom_target(${name} COMMAND ${ARGN}
      USES_TERMINAL VERBATIM COMMAND_EXPAND_LISTS)
  else()
    add_custom_target(${name})
  endif()
  if(deps)
    add_dependencies(${name} ${deps})
  endif()
endfunction()

# --- Primary targets (Makefile: libs, libblis) ---
set(_libs "")
foreach(_t blis_static blis_shared)
  if(TARGET ${_t})
    list(APPEND _libs ${_t})
  endif()
endforeach()
_blis_target(libblis "${_libs}")
_blis_target(libs libblis)

# --- check-env* ---
# The CMake configure step already found every config table it needs and
# writes no config.mk or fragments to check, so these do nothing.
_blis_target(check-env-mk "")
_blis_target(check-env-fragments check-env-mk)
_blis_target(check-env-make-defs check-env-fragments)
_blis_target(check-env "check-env-make-defs;check-env-fragments;check-env-mk")

# --- flat-header, flat-cblas-header ---
add_custom_target(flat-header DEPENDS "${PROJECT_BINARY_DIR}/include/blis.h")
# blis_flat_headers holds cblas.h only when BLIS_ENABLE_CBLAS is ON.
_blis_target(flat-cblas-header blis_flat_headers)

# --- Test runs: the ctest labels and names of cmake/BlisTesting.cmake ---
set(_ctest "${CMAKE_CTEST_COMMAND}" --test-dir "${PROJECT_BINARY_DIR}"
    "$<$<BOOL:$<CONFIG>>:-C$<SEMICOLON>$<CONFIG>>" --output-on-failure)

# testsuite-run[-fast|-md|-salt]: test_libblis.x on one input set. ctest also
# applies the check-blistest.sh test (PASS and FAIL regexes), as checkblis* do.
_blis_target(testsuite-bin test_libblis.x)
_blis_target(testsuite-run      test_libblis.x ${_ctest} -L "^full$")
_blis_target(testsuite-run-fast test_libblis.x ${_ctest} -L "^fast$")
_blis_target(testsuite-run-md   test_libblis.x ${_ctest} -L "^mixed$")
_blis_target(testsuite-run-salt test_libblis.x ${_ctest} -L "^salt$")
_blis_target(testsuite testsuite-run)
_blis_target(testblis testsuite)
_blis_target(checkblis testsuite-run)
foreach(_v fast md salt)
  _blis_target(testblis-${_v} testsuite-run-${_v})
  _blis_target(checkblis-${_v} testsuite-run-${_v})
endforeach()

# blastest-run: the 12 drivers; run-<drv>: one driver (Makefile run-$(1)).
_blis_target(blastest-f2c f2c)
_blis_target(blastest-run blastest-bin ${_ctest} -L "^blastest$")
_blis_target(testblas blastest-run)
_blis_target(checkblas blastest-run)
foreach(_p s d c z)
  foreach(_l 1 2 3)
    set(_drv ${_p}blat${_l})
    _blis_target(run-${_drv} ${_drv}.x ${_ctest} -R "^blastest-${_drv}$")
  endforeach()
endforeach()

# --- Clean rules ---
# File paths use TARGET_*_DIR/NAME: TARGET_FILE would make the clean target
# build its target first (CMP0112).
set(_rm "${CMAKE_COMMAND}" -E rm -f)
# cmake -E rm fails on an empty file list (BUILD_TESTING off); make does not.
function(_blis_rm_cmd out)
  if(ARGN)
    set(${out} COMMAND ${_rm} ${ARGN} PARENT_SCOPE)
  endif()
endfunction()

# cleanh: the flattened headers.
_blis_target(cleanh "" ${_rm} "${PROJECT_BINARY_DIR}/include/blis.h"
                             "${PROJECT_BINARY_DIR}/include/cblas.h")

# cleanlib: every object of the build tree (make's obj/<config> also holds
# the testsuite and blastest objects) and the libraries.
set(_lib_files "")
if(TARGET blis_static)
  list(APPEND _lib_files "$<TARGET_FILE_DIR:blis_static>/$<TARGET_FILE_NAME:blis_static>")
endif()
if(TARGET blis_shared)
  list(APPEND _lib_files "$<TARGET_FILE_DIR:blis_shared>/$<TARGET_FILE_NAME:blis_shared>"
       "$<TARGET_LINKER_FILE_DIR:blis_shared>/$<TARGET_LINKER_FILE_NAME:blis_shared>")
  if(NOT WIN32)
    list(APPEND _lib_files "$<TARGET_SONAME_FILE_DIR:blis_shared>/$<TARGET_SONAME_FILE_NAME:blis_shared>")
  endif()
endif()
_blis_rm_cmd(_rm_lib ${_lib_files})
_blis_target(cleanlib "" "${CMAKE_COMMAND}" -DDIR=${PROJECT_BINARY_DIR}
  -P "${CMAKE_CURRENT_LIST_FILE}" ${_rm_lib})

# cleanmk: CMake writes no .fragment.mk files, so this removes nothing.
_blis_target(cleanmk "")
# clean*testdir: make removes the results of an in-source testsuite/ or
# blastest/ build; CMake never builds into the source tree.
_blis_target(cleanblastestdir "")
_blis_target(cleanblistestdir "")

# cleanblastesttop: f2c and driver objects, libf2c, driver binaries, out.*.
set(_blat_files "")
if(TARGET f2c)
  list(APPEND _blat_files "$<TARGET_FILE_DIR:f2c>/$<TARGET_FILE_NAME:f2c>")
endif()
foreach(_p s d c z)
  foreach(_l 1 2 3)
    set(_drv ${_p}blat${_l})
    if(TARGET ${_drv}.x)
      list(APPEND _blat_files "$<TARGET_FILE_DIR:${_drv}.x>/$<TARGET_FILE_NAME:${_drv}.x>"
           "${PROJECT_BINARY_DIR}/blastest_run/${_drv}/out.driver"
           "${PROJECT_BINARY_DIR}/blastest_run/${_drv}/out.${_drv}")
    endif()
  endforeach()
endforeach()
_blis_rm_cmd(_rm_blastesttop ${_blat_files})
_blis_target(cleanblastesttop "" "${CMAKE_COMMAND}" -DDIR=${PROJECT_BINARY_DIR}/blastest
  -P "${CMAKE_CURRENT_LIST_FILE}" ${_rm_blastesttop})

# cleanblistesttop: testsuite objects and binary. The run output that make
# keeps in output.testsuite is in ctest's Testing/ dir.
set(_ts_files "")
if(TARGET test_libblis.x)
  set(_ts_files "$<TARGET_FILE_DIR:test_libblis.x>/$<TARGET_FILE_NAME:test_libblis.x>")
endif()
_blis_rm_cmd(_rm_blistesttop ${_ts_files})
_blis_target(cleanblistesttop "" "${CMAKE_COMMAND}" -DDIR=${PROJECT_BINARY_DIR}/testsuite
  -P "${CMAKE_CURRENT_LIST_FILE}" ${_rm_blistesttop})

_blis_target(cleanblastest "cleanblastesttop;cleanblastestdir")
_blis_target(cleanblistest "cleanblistesttop;cleanblistestdir")
_blis_target(cleantest "cleanblastest;cleanblistest")

# distclean: also the configure outputs (bli_config.h, bli_addon.h, config.mk,
# blis.pc), lib/ and include/. Make then needs ./configure again. Here the
# touched CMakeCache.txt makes the next build run the configure step again.
_blis_target(distclean "cleanmk;cleanh;cleanlib;cleantest"
  ${_rm} "${PROJECT_BINARY_DIR}/bli_config.h" "${PROJECT_BINARY_DIR}/bli_addon.h"
         "${PROJECT_BINARY_DIR}/make-share/config.mk" "${PROJECT_BINARY_DIR}/blis.pc"
  COMMAND "${CMAKE_COMMAND}" -E rm -rf "${PROJECT_BINARY_DIR}/lib" "${PROJECT_BINARY_DIR}/include"
  COMMAND "${CMAKE_COMMAND}" -E touch "${PROJECT_BINARY_DIR}/CMakeCache.txt")
