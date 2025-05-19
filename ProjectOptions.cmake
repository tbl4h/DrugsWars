include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(DrugsWars_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(DrugsWars_setup_options)
  option(DrugsWars_ENABLE_HARDENING "Enable hardening" ON)
  option(DrugsWars_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    DrugsWars_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    DrugsWars_ENABLE_HARDENING
    OFF)

  DrugsWars_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR DrugsWars_PACKAGING_MAINTAINER_MODE)
    option(DrugsWars_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(DrugsWars_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(DrugsWars_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(DrugsWars_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(DrugsWars_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(DrugsWars_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(DrugsWars_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(DrugsWars_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(DrugsWars_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(DrugsWars_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(DrugsWars_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(DrugsWars_ENABLE_PCH "Enable precompiled headers" OFF)
    option(DrugsWars_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(DrugsWars_ENABLE_IPO "Enable IPO/LTO" ON)
    option(DrugsWars_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(DrugsWars_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(DrugsWars_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(DrugsWars_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(DrugsWars_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(DrugsWars_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(DrugsWars_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(DrugsWars_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(DrugsWars_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(DrugsWars_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(DrugsWars_ENABLE_PCH "Enable precompiled headers" OFF)
    option(DrugsWars_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      DrugsWars_ENABLE_IPO
      DrugsWars_WARNINGS_AS_ERRORS
      DrugsWars_ENABLE_USER_LINKER
      DrugsWars_ENABLE_SANITIZER_ADDRESS
      DrugsWars_ENABLE_SANITIZER_LEAK
      DrugsWars_ENABLE_SANITIZER_UNDEFINED
      DrugsWars_ENABLE_SANITIZER_THREAD
      DrugsWars_ENABLE_SANITIZER_MEMORY
      DrugsWars_ENABLE_UNITY_BUILD
      DrugsWars_ENABLE_CLANG_TIDY
      DrugsWars_ENABLE_CPPCHECK
      DrugsWars_ENABLE_COVERAGE
      DrugsWars_ENABLE_PCH
      DrugsWars_ENABLE_CACHE)
  endif()

  DrugsWars_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (DrugsWars_ENABLE_SANITIZER_ADDRESS OR DrugsWars_ENABLE_SANITIZER_THREAD OR DrugsWars_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(DrugsWars_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(DrugsWars_global_options)
  if(DrugsWars_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    DrugsWars_enable_ipo()
  endif()

  DrugsWars_supports_sanitizers()

  if(DrugsWars_ENABLE_HARDENING AND DrugsWars_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR DrugsWars_ENABLE_SANITIZER_UNDEFINED
       OR DrugsWars_ENABLE_SANITIZER_ADDRESS
       OR DrugsWars_ENABLE_SANITIZER_THREAD
       OR DrugsWars_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${DrugsWars_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${DrugsWars_ENABLE_SANITIZER_UNDEFINED}")
    DrugsWars_enable_hardening(DrugsWars_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(DrugsWars_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(DrugsWars_warnings INTERFACE)
  add_library(DrugsWars_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  DrugsWars_set_project_warnings(
    DrugsWars_warnings
    ${DrugsWars_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(DrugsWars_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    DrugsWars_configure_linker(DrugsWars_options)
  endif()

  include(cmake/Sanitizers.cmake)
  DrugsWars_enable_sanitizers(
    DrugsWars_options
    ${DrugsWars_ENABLE_SANITIZER_ADDRESS}
    ${DrugsWars_ENABLE_SANITIZER_LEAK}
    ${DrugsWars_ENABLE_SANITIZER_UNDEFINED}
    ${DrugsWars_ENABLE_SANITIZER_THREAD}
    ${DrugsWars_ENABLE_SANITIZER_MEMORY})

  set_target_properties(DrugsWars_options PROPERTIES UNITY_BUILD ${DrugsWars_ENABLE_UNITY_BUILD})

  if(DrugsWars_ENABLE_PCH)
    target_precompile_headers(
      DrugsWars_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(DrugsWars_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    DrugsWars_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(DrugsWars_ENABLE_CLANG_TIDY)
    DrugsWars_enable_clang_tidy(DrugsWars_options ${DrugsWars_WARNINGS_AS_ERRORS})
  endif()

  if(DrugsWars_ENABLE_CPPCHECK)
    DrugsWars_enable_cppcheck(${DrugsWars_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(DrugsWars_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    DrugsWars_enable_coverage(DrugsWars_options)
  endif()

  if(DrugsWars_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(DrugsWars_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(DrugsWars_ENABLE_HARDENING AND NOT DrugsWars_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR DrugsWars_ENABLE_SANITIZER_UNDEFINED
       OR DrugsWars_ENABLE_SANITIZER_ADDRESS
       OR DrugsWars_ENABLE_SANITIZER_THREAD
       OR DrugsWars_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    DrugsWars_enable_hardening(DrugsWars_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
