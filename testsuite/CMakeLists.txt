# The BLIS testsuite driver (test_libblis.x).
#
# Two modes:
#  * in-tree: driven by the top-level BLIS build (targets/flags supplied);
#    CTest entries are registered by cmake/BlisTesting.cmake.
#  * standalone: cmake -S <installed-or-source testsuite dir> -B build
#    -DCMAKE_PREFIX_PATH=<blis prefix>, then `cmake --build` and run the
#    binary from the (source) testsuite directory where input.general and
#    input.operations live.

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  cmake_minimum_required(VERSION 4.0)
  project(blis-testsuite C)
  find_package(blis REQUIRED)
  set(_blis_lib blis::blis)
  set(BLIS_TESTSUITE_STANDALONE ON)
else()
  set(_blis_lib ${BLIS_LINK_TARGET})
endif()

file(GLOB _ts_srcs CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c")
add_executable(test_libblis.x ${_ts_srcs})
target_include_directories(test_libblis.x PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
target_link_libraries(test_libblis.x PRIVATE ${_blis_lib})

if(BLIS_TESTSUITE_STANDALONE)
  if(NOT MSVC)
    target_link_libraries(test_libblis.x PRIVATE m)
  endif()
else()
  blis_get_cflags("${BLIS_CONFIG_NAME}" user _uflags)
  target_compile_options(test_libblis.x PRIVATE ${_uflags})
  target_include_directories(test_libblis.x PRIVATE
    "${PROJECT_BINARY_DIR}/include" ${BLIS_CINCDIRS})
  target_link_libraries(test_libblis.x PRIVATE ${BLIS_LINK_LIBS})
  add_dependencies(test_libblis.x blis_flat_headers)
endif()
