# Example programs (examples/oapi, examples/tapi). Each source is a
# standalone program linked against BLIS. Usable in-tree (via the top-level
# BLIS build) or standalone against an installed BLIS:
#   cmake -S <src>/examples -B <build> -DCMAKE_PREFIX_PATH=<blis prefix>

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  cmake_minimum_required(VERSION 4.0)
  project(blis-examples C)
  find_package(blis REQUIRED)
  set(_blis_lib blis::blis)
  set(_in_tree OFF)
else()
  set(_blis_lib ${BLIS_LINK_TARGET})
  set(_in_tree ON)
  blis_get_cflags("${BLIS_CONFIG_NAME}" user _uflags)
endif()

foreach(dir oapi tapi)
  file(GLOB _examples CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.c")
  foreach(src ${_examples})
    get_filename_component(name "${src}" NAME_WE)
    set(tgt "example-${dir}-${name}")
    add_executable(${tgt} ${src})
    target_link_libraries(${tgt} PRIVATE ${_blis_lib})
    if(_in_tree)
      target_compile_options(${tgt} PRIVATE ${_uflags})
      target_include_directories(${tgt} PRIVATE
        "${PROJECT_BINARY_DIR}/include" ${BLIS_CINCDIRS})
      target_link_libraries(${tgt} PRIVATE ${BLIS_LINK_LIBS})
      add_dependencies(${tgt} blis_flat_headers)
      set_target_properties(${tgt} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/examples/${dir}")
    elseif(NOT MSVC)
      target_link_libraries(${tgt} PRIVATE m)
    endif()
  endforeach()
endforeach()
