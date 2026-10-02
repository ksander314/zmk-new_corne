if(CONFIG_ZMK_DISPLAY AND CONFIG_NICE_VIEW_WIDGET_STATUS)
  zephyr_library_include_directories(${CMAKE_SOURCE_DIR}/include)
  zephyr_library_sources(custom_status_screen.c)
  zephyr_library_sources(widgets/bolt.c)
  zephyr_library_sources(widgets/util.c)

  # Short sha of the commit this firmware is built from, drawn on the display so a
  # flash can be checked against `git log`. In CI only this module directory is a
  # git checkout (config/ is copied to a temp dir); the build container runs as a
  # different user than the checkout, hence safe.directory.
  execute_process(
    COMMAND git -c safe.directory=* rev-parse --short=7 HEAD
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE KB_BUILD_SHA
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
    RESULT_VARIABLE kb_build_sha_result)
  if(NOT kb_build_sha_result EQUAL 0 OR KB_BUILD_SHA STREQUAL "")
    set(KB_BUILD_SHA "unknown")
  endif()
  zephyr_library_compile_definitions(KB_BUILD_SHA="${KB_BUILD_SHA}")

  if(NOT CONFIG_ZMK_SPLIT OR CONFIG_ZMK_SPLIT_ROLE_CENTRAL)
    zephyr_library_sources(widgets/status.c)
  else()
    zephyr_library_sources(widgets/art.c)
    zephyr_library_sources(widgets/peripheral_status.c)
  endif()
endif()
