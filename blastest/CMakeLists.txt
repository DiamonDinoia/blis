# The netlib BLAS test drivers (blastest; f2c-translated sources).
#
# Two modes: in-tree (top-level BLIS build; CTest entries registered by
# cmake/BlisTesting.cmake) or standalone against an installed BLIS
# (find_package(blis)).

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  cmake_minimum_required(VERSION 4.0)
  project(blis-blastest C)
  find_package(blis REQUIRED)
  set(_blis_lib blis::blis)
  set(_in_tree OFF)
  set(_blis_inc ${blis_INCLUDE_DIRS})
else()
  set(_blis_lib ${BLIS_LINK_TARGET})
  set(_in_tree ON)
  set(_blis_inc "${PROJECT_BINARY_DIR}/include")
  blis_get_cflags("${BLIS_CONFIG_NAME}" user _uflags)
endif()

file(GLOB _f2c_srcs CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/f2c/*.c")
add_library(f2c STATIC ${_f2c_srcs})
target_include_directories(f2c PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/f2c" ${_blis_inc})
target_compile_options(f2c PRIVATE -Wno-parentheses -DHAVE_BLIS_H)
set_target_properties(f2c PROPERTIES POSITION_INDEPENDENT_CODE ON)

set(_blat_extra -Wno-parentheses -DHAVE_BLIS_H)
if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  list(APPEND _blat_extra -Wno-maybe-uninitialized)
  target_compile_options(f2c PRIVATE -Wno-maybe-uninitialized)
endif()

foreach(p s d c z)
  foreach(l 1 2 3)
    set(drv "${p}blat${l}")
    add_executable(${drv}.x "${CMAKE_CURRENT_SOURCE_DIR}/src/${drv}.c")
    target_compile_options(${drv}.x PRIVATE ${_blat_extra})
    target_include_directories(${drv}.x PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/f2c")
    target_link_libraries(${drv}.x PRIVATE f2c ${_blis_lib})
    list(APPEND _blat_drivers ${drv}.x)
  endforeach()
endforeach()

# make blastest-bin: the f2c library plus every driver binary.
add_custom_target(blastest-bin)
add_dependencies(blastest-bin f2c ${_blat_drivers})

if(_in_tree)
  # f2c + drivers get the make system's user flags; f2c only needs the
  # flat-header include for HAVE_BLIS_H.
  target_compile_options(f2c PRIVATE ${_uflags})
  target_include_directories(f2c PRIVATE "${PROJECT_BINARY_DIR}/include")
  add_dependencies(f2c blis_flat_headers)
  foreach(p s d c z)
    foreach(l 1 2 3)
      set(drv "${p}blat${l}")
      target_compile_options(${drv}.x PRIVATE ${_uflags})
      target_include_directories(${drv}.x PRIVATE
        "${PROJECT_BINARY_DIR}/include" ${BLIS_CINCDIRS} "${PROJECT_BINARY_DIR}")
      target_link_libraries(${drv}.x PRIVATE ${BLIS_LINK_LIBS})
      add_dependencies(${drv}.x blis_flat_headers)
    endforeach()
  endforeach()
else()
  if(NOT MSVC)
    target_link_libraries(f2c PUBLIC m)
  endif()
endif()
