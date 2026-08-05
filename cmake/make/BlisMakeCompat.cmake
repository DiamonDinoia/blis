# Make-build parity: the share/blis make fragments (Makefile install-share),
# the showconfig target and the uninstall-old targets.
# Included from the top-level CMakeLists.txt after the install rules.

function(_blis_yn out)
  if(${ARGN})
    set(${out} yes PARENT_SCOPE)
  else()
    set(${out} no PARENT_SCOPE)
  endif()
endfunction()

# One showconfig line, label padded to the width the Makefile uses.
function(_blis_row label value)
  string(LENGTH "${label}" _n)
  math(EXPR _pad "28 - ${_n}")
  string(REPEAT " " ${_pad} _sp)
  string(APPEND _showconfig "${label}${_sp}${value}\n")
  set(_showconfig "${_showconfig}" PARENT_SCOPE)
endfunction()

# Anchor values for build/config.mk.in. Names match the template's @anchors@.
set(version "${BLIS_VERSION}")
set(so_version_major "${BLIS_SO_MAJOR}")
set(so_version_minorbuild "${BLIS_SO_MINORB}")
set(config_name "${BLIS_CONFIG_NAME}")
string(JOIN " " config_list ${BLIS_CONFIG_LIST})
string(JOIN " " kernel_list ${BLIS_KERNEL_LIST})
string(JOIN " " kconfig_map ${BLIS_KCONFIG_MAP})

# configure adds every registry name before it applies blacklists; singleton
# families also contribute their subconfig and kernel sets.
set(_fc "")
set(_fs "")
set(_fk "")
foreach(n ${BLIS_REG_NAMES})
  list(APPEND _fc ${n})
  if("${BLIS_REG_CONFIG_${n}}" STREQUAL "${n}")
    list(APPEND _fs ${n})
    # raw klist, before the fixpoint (configure line 746)
    list(APPEND _fk ${BLIS_REG_RAW_KERNELS_${n}})
  endif()
endforeach()
list(REMOVE_DUPLICATES _fk)
string(JOIN " " full_config_list ${_fc})
string(JOIN " " full_subconfig_list ${_fs})
string(JOIN " " full_kernel_list ${_fk})

set(os_name "${CMAKE_SYSTEM_NAME}")
_blis_yn(is_win WIN32)
_blis_yn(is_msvc MSVC)
set(dist_path "${BLIS_SOURCE_DIR}")
set(CC_VENDOR "${BLIS_CC_VENDOR}")
foreach(v 4_9_0 6_1_0 9_1_0 10_3_0)
  set(gcc_older_than_${v} "${BLIS_GCC_OT_${v}}")
endforeach()
foreach(v 9_0_0 12_0_0)
  set(clang_older_than_${v} "${BLIS_CLANG_OT_${v}}")
endforeach()
foreach(v 2_0_0 3_0_0)
  set(aocc_older_than_${v} "${BLIS_AOCC_OT_${v}}")
endforeach()
set(CC "${CMAKE_C_COMPILER}")
if(CMAKE_CXX_COMPILER)
  set(CXX "${CMAKE_CXX_COMPILER}")
else()
  find_program(CXX NAMES g++ clang++ c++)
endif()
if(DEFINED ENV{FC})
  set(FC "$ENV{FC}")
else()
  find_program(FC NAMES gfortran ifort ifx nvfortran)
endif()
set(AR "${CMAKE_AR}")
set(RANLIB "${CMAKE_RANLIB}")
set(PYTHON "${Python3_EXECUTABLE}")
set(cflags_preset "${CMAKE_C_FLAGS}")
if(DEFINED CMAKE_CXX_FLAGS)
  set(cxxflags_preset "${CMAKE_CXX_FLAGS}")
else()
  set(cxxflags_preset "$ENV{CXXFLAGS}")  # no C++ language enabled in a C-only build
endif()
string(JOIN " " ldflags_preset ${BLIS_LDFLAGS_PRESET})
set(debug_type "${BLIS_DEBUG_TYPE}")
_blis_yn(enable_debug NOT "${BLIS_DEBUG_TYPE}" STREQUAL "off")
_blis_yn(enable_asan BLIS_ENABLE_ASAN)
_blis_yn(mk_enable_system BLIS_ENABLE_SYSTEM)
string(JOIN " " threading_model ${BLIS_THREADING_MODELS})
set(pragma_omp_simd "${BLIS_PRAGMA_OMP_SIMD}")
set(libpthread "-lpthread")
if((WIN32 AND BLIS_CC_VENDOR STREQUAL "clang") OR NOT BLIS_ENABLE_SYSTEM)
  set(libpthread "")
endif()
set(enable_verbose no)
set(configured_oot yes)
set(enable_arg_max_hack no)
_blis_yn(mk_enable_static BLIS_ENABLE_STATIC)
_blis_yn(mk_enable_shared BLIS_ENABLE_SHARED)
_blis_yn(enable_rpath APPLE AND BLIS_DARWIN_RPATH)
set(export_shared "${BLIS_EXPORT_SHARED}")
_blis_yn(mk_enable_blas BLIS_EFFECTIVE_BLAS)
_blis_yn(mk_enable_cblas BLIS_ENABLE_CBLAS)
_blis_yn(mk_enable_memkind enable_memkind)
string(JOIN " " addon_list ${BLIS_ENABLE_ADDONS})
set(sandbox "${BLIS_SANDBOX}")
_blis_yn(enable_amd_frame_tweaks BLIS_ENABLE_AMD_FRAME_TWEAKS)

# Install locations, written the way configure writes them. The prefix is a
# placeholder that the install step replaces, so `cmake --install --prefix`
# yields a config.mk that matches the actual install.
set(prefix "@BLIS_INSTALL_PREFIX@")
if(NOT "${BLIS_INSTALL_EXEC_PREFIX}" STREQUAL "")
  set(exec_prefix "${BLIS_INSTALL_EXEC_PREFIX}")
else()
  set(exec_prefix "\${prefix}")
endif()
if(IS_ABSOLUTE "${BLIS_INSTALL_LIBDIR}")
  set(libdir "${BLIS_INSTALL_LIBDIR}")
else()
  set(libdir "\${exec_prefix}/${BLIS_INSTALL_LIBDIR}")
endif()
if(IS_ABSOLUTE "${CMAKE_INSTALL_INCLUDEDIR}")
  set(includedir "${CMAKE_INSTALL_INCLUDEDIR}")
else()
  set(includedir "\${prefix}/${CMAKE_INSTALL_INCLUDEDIR}")
endif()
if(NOT "${BLIS_INSTALL_SHAREDIR}" STREQUAL "")
  set(sharedir "${BLIS_INSTALL_SHAREDIR}")
elseif(IS_ABSOLUTE "${CMAKE_INSTALL_DATAROOTDIR}")
  set(sharedir "${CMAKE_INSTALL_DATAROOTDIR}")
else()
  set(sharedir "\${prefix}/${CMAKE_INSTALL_DATAROOTDIR}")
endif()

set(_mkdir "${PROJECT_BINARY_DIR}/make-share")
configure_file("${BLIS_SOURCE_DIR}/build/config.mk.in" "${_mkdir}/config.mk" @ONLY)

# --- install share/blis (Makefile: install-share) ---
set(_share "${BLIS_SHAREDIR}/blis")
set(_src "${BLIS_SOURCE_DIR}")
install(FILES
  "${_src}/common.mk"
  "${_src}/config_registry"
  "${_src}/build/flatten-headers.py"
  "${_src}/build/gen-make-frags/fragment.mk"
  "${_src}/build/gen-make-frags/ignore_list"
  "${_src}/build/gen-make-frags/special_list"
  "${_src}/build/gen-make-frags/suffix_list"
  "${_src}/build/detect/iset/avx.s"
  "${_src}/build/detect/iset/avx512dq.s"
  "${_src}/build/detect/iset/avx512f.s"
  "${_src}/build/detect/iset/fma3.s"
  "${_src}/build/detect/iset/fma4.s"
  DESTINATION ${_share} COMPONENT share)
install(PROGRAMS
  "${_src}/build/gen-make-frags/gen-make-frag.sh"
  "${_src}/build/mirror-tree.sh"
  DESTINATION ${_share} COMPONENT share)
install(PROGRAMS "${_src}/configure" DESTINATION ${_share} RENAME configure-plugin COMPONENT share)
install(FILES
  "${_src}/build/plugin/bli_plugin_init_ref.c"
  "${_src}/build/plugin/bli_plugin_init_zen3.c"
  "${_src}/build/plugin/bli_plugin_register.c"
  "${_src}/build/plugin/my_kernel_1_ref.c"
  "${_src}/build/plugin/my_kernel_2_ref.c"
  "${_src}/build/plugin/my_kernel_1_zen3.c"
  "${_src}/build/plugin/bli_plugin.h.in"
  "${_src}/build/plugin/config.mk.in"
  "${_src}/build/plugin/Makefile"
  DESTINATION ${_share}/plugin COMPONENT share)
# Like the Makefile loop, skip a config that lacks one of the two files.
foreach(c ${_fc})
  foreach(f make_defs.mk bli_kernel_defs_${c}.h)
    if(EXISTS "${_src}/config/${c}/${f}")
      install(FILES "${_src}/config/${c}/${f}" DESTINATION ${_share}/config/${c} COMPONENT share)
    endif()
  endforeach()
endforeach()

# config.mk is installed through file(INSTALL) so it lands in the install
# manifest (uninstall) and honors DESTDIR.
install(CODE "set(_blis_cfgmk \"${_mkdir}/config.mk\")
set(_blis_share \"${_share}\")" COMPONENT share)
install(CODE [[
  file(READ "${_blis_cfgmk}" _c)
  string(REPLACE "@BLIS_INSTALL_PREFIX@" "${CMAKE_INSTALL_PREFIX}" _c "${_c}")
  file(WRITE "${_blis_cfgmk}.d/config.mk" "${_c}")
  cmake_path(ABSOLUTE_PATH _blis_share BASE_DIRECTORY "${CMAKE_INSTALL_PREFIX}")
  file(INSTALL "${_blis_cfgmk}.d/config.mk" DESTINATION "${_blis_share}"
       PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
]] COMPONENT share)

# --- showconfig (Makefile: showconfig) ---
set(_showconfig "")
_blis_row("configuration family:" "${config_name}")
_blis_row("sub-configurations:" "${config_list}")
_blis_row("requisite kernels sets:" "${kernel_list}")
_blis_row("kernel-to-config map:" "${kconfig_map}")
string(APPEND _showconfig "-------------------------\n")
_blis_row("BLIS version string:" "${version}")
_blis_row(".so major version:" "${so_version_major}")
_blis_row(".so minor.build vers:" "${so_version_minorbuild}")
set(_eff_incdir "${CMAKE_INSTALL_INCLUDEDIR}")
cmake_path(ABSOLUTE_PATH _eff_incdir BASE_DIRECTORY "${CMAKE_INSTALL_PREFIX}")
set(_eff_sharedir "${BLIS_SHAREDIR}")
cmake_path(ABSOLUTE_PATH _eff_sharedir BASE_DIRECTORY "${CMAKE_INSTALL_PREFIX}")
_blis_row("install libdir:" "${BLIS_INSTALL_FULL_LIBDIR}")
_blis_row("install includedir:" "${_eff_incdir}")
_blis_row("install sharedir:" "${_eff_sharedir}")
_blis_row("debugging status:" "${debug_type}")
_blis_row("enable AddressSanitizer?" "${enable_asan}")
_blis_row("enabled threading model(s):" "${threading_model}")
_blis_row("enable BLAS API?" "${mk_enable_blas}")
_blis_row("enable CBLAS API?" "${mk_enable_cblas}")
_blis_row("build static library?" "${mk_enable_static}")
_blis_row("build shared library?" "${mk_enable_shared}")
_blis_row("ARG_MAX hack enabled?" "${enable_arg_max_hack}")
file(WRITE "${PROJECT_BINARY_DIR}/showconfig.txt" "${_showconfig}")
add_custom_target(showconfig
  COMMAND "${CMAKE_COMMAND}" -E cat "${PROJECT_BINARY_DIR}/showconfig.txt"
  VERBATIM)

# --- install record: every uninstall target reads it ---
# Each install (full or per component) writes the prefix and DESTDIR it used,
# so the uninstall targets act on the last install of this build dir, as
# make's uninstall acts on the prefix make installed to. Without a record the
# uninstall targets use the configured prefix and the DESTDIR environment.
set(_blis_record "${PROJECT_BINARY_DIR}/blis_install_record.cmake")
# Both values are made absolute here, against the working directory of the
# install call, as `cmake --install` resolves them. Uninstall never resolves
# a recorded path against its own directory.
foreach(_c headers helper-headers libs lib-symlinks share cmake-package)
  install(CODE "set(_blis_record \"${_blis_record}\")" COMPONENT ${_c})
  install(CODE [[
    set(_p "${CMAKE_INSTALL_PREFIX}")
    set(_d "$ENV{DESTDIR}")
    cmake_path(ABSOLUTE_PATH _p NORMALIZE)
    if(NOT "${_d}" STREQUAL "")
      cmake_path(ABSOLUTE_PATH _d NORMALIZE)
    endif()
    file(WRITE "${_blis_record}"
      "set(blis_rec_prefix [==[${_p}]==])\nset(blis_rec_destdir [==[${_d}]==])\n")
  ]] COMPONENT ${_c})
endforeach()
set(_blis_unargs "-DRECORD=${_blis_record}" "-DPREFIX=${CMAKE_INSTALL_PREFIX}")

# --- uninstall-old (Makefile: uninstall-old-libs/-symlinks/-headers) ---
add_custom_target(uninstall-old)
foreach(w libs symlinks headers)
  add_custom_target(uninstall-old-${w}
    COMMAND "${CMAKE_COMMAND}" -DWHAT=${w}
      -DLIBDIR=${BLIS_INSTALL_LIBDIR} -DINCDIR=${CMAKE_INSTALL_INCLUDEDIR}
      -DSO_MAJOR=${BLIS_SO_MAJOR} -DSO_MMB=${BLIS_SO_MMB} -DDARWIN=${APPLE}
      ${_blis_unargs}
      -P "${BLIS_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
    VERBATIM)
  add_dependencies(uninstall-old uninstall-old-${w})
endforeach()

# --- partial install (Makefile: install-headers, install-helper-headers,
# install-libs, install-lib-symlinks, install-share) ---
# install-X runs the install rules tagged COMPONENT X, the same set
# `cmake --install DIR --component X` installs. Like make, it builds first.
# make's install-headers also runs install-helper-headers.
set(_ic_headers headers helper-headers)
foreach(_n helper-headers libs lib-symlinks share)
  set(_ic_${_n} ${_n})
endforeach()
set(_blis_libtargets "")
foreach(_t blis_static blis_shared)
  if(TARGET ${_t})
    list(APPEND _blis_libtargets ${_t})
  endif()
endforeach()
foreach(_n headers helper-headers libs lib-symlinks share)
  set(_cmds "")
  foreach(_c ${_ic_${_n}})
    list(APPEND _cmds COMMAND "${CMAKE_COMMAND}" -DCMAKE_INSTALL_COMPONENT=${_c}
         -P "${PROJECT_BINARY_DIR}/cmake_install.cmake")
  endforeach()
  add_custom_target(install-${_n} ${_cmds} VERBATIM)
  if(_n MATCHES "headers$")
    add_dependencies(install-${_n} blis_flat_headers)
  elseif(_n MATCHES "^lib")
    add_dependencies(install-${_n} ${_blis_libtargets})
  endif()
endforeach()

# --- uninstall (Makefile: uninstall-libs, -lib-symlinks, -headers, -share) ---
# The names come from the layout. A relative one is resolved against the
# recorded install prefix when the target runs.
# Lists travel as "|"-joined strings, because ";" would split the argument.
set(_ul_libs "")
set(_ul_syml "")
if(TARGET blis_static)
  list(APPEND _ul_libs "${BLIS_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:blis_static>")
endif()
if(TARGET blis_shared)
  list(APPEND _ul_libs "${BLIS_INSTALL_LIBDIR}/$<TARGET_FILE_NAME:blis_shared>")
  if(NOT WIN32)
    list(APPEND _ul_syml "${BLIS_INSTALL_LIBDIR}/$<TARGET_SONAME_FILE_NAME:blis_shared>"
         "${BLIS_INSTALL_LIBDIR}/$<TARGET_LINKER_FILE_NAME:blis_shared>")
  endif()
endif()
set(_ul_hdrs "${CMAKE_INSTALL_INCLUDEDIR}/blis" "${CMAKE_INSTALL_INCLUDEDIR}/blis.h")
if(BLIS_ENABLE_CBLAS)
  list(APPEND _ul_hdrs "${CMAKE_INSTALL_INCLUDEDIR}/cblas.h")
endif()
foreach(_n libs lib-symlinks headers share)
  set(_f "")
  set(_d "")
  if(_n STREQUAL "libs")
    list(JOIN _ul_libs "|" _f)
  elseif(_n STREQUAL "lib-symlinks")
    list(JOIN _ul_syml "|" _f)
  elseif(_n STREQUAL "headers")
    list(JOIN _ul_hdrs "|" _d)
  else()
    set(_d "${BLIS_SHAREDIR}/blis")
  endif()
  add_custom_target(uninstall-${_n}
    COMMAND "${CMAKE_COMMAND}" "-DFILES=${_f}" "-DDIRS=${_d}" ${_blis_unargs}
      -P "${BLIS_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
    VERBATIM)
endforeach()
# blis.pc and the CMake package have no make counterpart, so only `uninstall`
# removes them.
add_custom_target(uninstall
  COMMAND "${CMAKE_COMMAND}" "-DDIRS=${BLIS_INSTALL_LIBDIR}/cmake/blis|${BLIS_SHAREDIR}/pkgconfig/blis.pc" ${_blis_unargs}
    -P "${BLIS_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
  VERBATIM)
add_dependencies(uninstall uninstall-libs uninstall-lib-symlinks
                 uninstall-headers uninstall-share)
