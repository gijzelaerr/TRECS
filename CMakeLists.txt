######################################################
# T-RECS: The Tiered Radio Extragalactic Continuum #
# CMake Build System                                #
######################################################

cmake_minimum_required(VERSION 3.12)
project(TRECS
    VERSION 1.0.0
    DESCRIPTION "The Tiered Radio Extragalactic Continuum Simulation"
    LANGUAGES Fortran C
)

# Set default build type to Release
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Enable OpenMP support (optional for performance)
find_package(OpenMP)

# Set Fortran compiler flags
if(OpenMP_Fortran_FOUND)
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} ${OpenMP_Fortran_FLAGS}")
endif()
set(CMAKE_Fortran_FLAGS_RELEASE "-O3")
set(CMAKE_Fortran_FLAGS_DEBUG "-g -O0 -Wall -Wextra")

# Set module directory
set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

###############################################################################################
# Find required libraries

# GSL
find_package(PkgConfig REQUIRED)
pkg_check_modules(GSL REQUIRED gsl)

# CFITSIO
find_path(CFITSIO_INCLUDE_DIR fitsio.h
    HINTS ENV CFITSIO_DIR
    PATH_SUFFIXES include
)
find_library(CFITSIO_LIBRARY cfitsio
    HINTS ENV CFITSIO_DIR
    PATH_SUFFIXES lib
)
if(NOT CFITSIO_INCLUDE_DIR OR NOT CFITSIO_LIBRARY)
    message(FATAL_ERROR "CFITSIO not found. Set CFITSIO_DIR environment variable or install CFITSIO.")
endif()

# HEALPIX - Try to find Fortran modules first, fallback to C interface
find_path(HEALPIX_FORTRAN_DIR healpix_types.mod
    HINTS ENV HEALPIX_DIR
    PATH_SUFFIXES include lib/fortran/mod
)

if(HEALPIX_FORTRAN_DIR)
    # Found Fortran modules - use them
    set(HEALPIX_INCLUDE_DIR ${HEALPIX_FORTRAN_DIR})
    find_library(HEALPIX_LIBRARY healpix
        HINTS ENV HEALPIX_DIR
        PATH_SUFFIXES lib
    )
    message(STATUS "Found HEALPIX Fortran modules at: ${HEALPIX_FORTRAN_DIR}")
else()
    # Fallback to C interface (Homebrew)
    find_path(HEALPIX_INCLUDE_DIR chealpix.h
        HINTS ENV HEALPIX_DIR /opt/homebrew/Cellar/healpix/3.83_1
        PATH_SUFFIXES include
    )
    find_library(HEALPIX_LIBRARY chealpix
        HINTS ENV HEALPIX_DIR /opt/homebrew/Cellar/healpix/3.83_1
        PATH_SUFFIXES lib
    )
    message(WARNING "Found only HEALPIX C interface. T-RECS requires Fortran modules. See CLAUDE.md for installation instructions.")
endif()

find_library(GIF_LIBRARY gif
    HINTS ENV HEALPIX_DIR /opt/homebrew/Cellar/healpix/3.83_1
    PATH_SUFFIXES lib
)

if(NOT HEALPIX_INCLUDE_DIR OR NOT HEALPIX_LIBRARY)
    message(FATAL_ERROR "HEALPIX not found. Set HEALPIX_DIR environment variable or install HEALPIX with Fortran support. See CLAUDE.md for instructions.")
endif()

# LAPACK
find_package(LAPACK REQUIRED)

# Python (for script installation)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

###############################################################################################
# Create interface libraries for external dependencies

add_library(GSL_interface INTERFACE)
target_link_libraries(GSL_interface INTERFACE ${GSL_LDFLAGS})
target_include_directories(GSL_interface INTERFACE ${GSL_INCLUDE_DIRS})
target_compile_options(GSL_interface INTERFACE ${GSL_CFLAGS_OTHER})

add_library(CFITSIO_interface INTERFACE)
target_link_libraries(CFITSIO_interface INTERFACE ${CFITSIO_LIBRARY})
target_include_directories(CFITSIO_interface INTERFACE ${CFITSIO_INCLUDE_DIR})

add_library(HEALPIX_interface INTERFACE)
target_link_libraries(HEALPIX_interface INTERFACE ${HEALPIX_LIBRARY})
if(GIF_LIBRARY)
    target_link_libraries(HEALPIX_interface INTERFACE ${GIF_LIBRARY})
endif()
# Also link the C HEALPIX library for C functions like ang2pix_ring_
find_library(HEALPIX_C_LIBRARY chealpix HINTS ENV HEALPIX_DIR /opt/homebrew/Cellar/healpix/3.83_1 PATH_SUFFIXES lib)
if(HEALPIX_C_LIBRARY)
    target_link_libraries(HEALPIX_interface INTERFACE ${HEALPIX_C_LIBRARY})
endif()
target_include_directories(HEALPIX_interface INTERFACE ${HEALPIX_INCLUDE_DIR})

# Add HEALPIX compiled object files if Fortran modules are available
if(HEALPIX_FORTRAN_DIR)
    file(GLOB HEALPIX_OBJECTS "${CMAKE_SOURCE_DIR}/external/Healpix_3.83/fortran_build/*.o")
    target_link_libraries(HEALPIX_interface INTERFACE ${HEALPIX_OBJECTS})
endif()

add_library(LAPACK_interface INTERFACE)
target_link_libraries(LAPACK_interface INTERFACE ${LAPACK_LIBRARIES})

###############################################################################################
# Define source files

set(TRECS_MODULE_SOURCES
    src/random_modules.f90
    src/sampler_io.f90
    src/sampler_modules.f90
)

set(CONTINUUM_SOURCES
    src/sampler_continuum.f90
)

set(HI_SOURCES
    src/sampler_hi.f90
)

set(WRAPPER_SOURCES
    src/wrapper.f90
)

###############################################################################################
# Build Fortran executables

# Create module library first (required by other executables)
add_library(trecs_modules STATIC ${TRECS_MODULE_SOURCES})
target_link_libraries(trecs_modules
    PUBLIC
    GSL_interface
    CFITSIO_interface
    HEALPIX_interface
    LAPACK_interface
)
if(OpenMP_Fortran_FOUND)
    target_link_libraries(trecs_modules PUBLIC OpenMP::OpenMP_Fortran)
endif()
target_include_directories(trecs_modules
    PUBLIC
    ${CMAKE_Fortran_MODULE_DIRECTORY}
)

# Continuum sampler executable
add_executable(trecs_sampler_continuum ${CONTINUUM_SOURCES})
target_link_libraries(trecs_sampler_continuum
    PRIVATE
    trecs_modules
)

# HI sampler executable
add_executable(trecs_sampler_hi ${HI_SOURCES})
target_link_libraries(trecs_sampler_hi
    PRIVATE
    trecs_modules
)

# Wrapper executable
add_executable(trecs_wrapper ${WRAPPER_SOURCES})
target_link_libraries(trecs_wrapper
    PRIVATE
    trecs_modules
)

###############################################################################################
# Configure Python scripts

set(PYTHON_SCRIPTS
    python/xmatch_hi.py
    python/xmatch_clustering.py
    python/addkeys_vizier.py
)

# Configure Python scripts with proper shebang
foreach(script ${PYTHON_SCRIPTS})
    get_filename_component(script_name ${script} NAME_WE)
    set(output_script ${CMAKE_BINARY_DIR}/bin/trecs_${script_name})

    configure_file(
        ${CMAKE_CURRENT_SOURCE_DIR}/${script}
        ${output_script}
        @ONLY
    )

    # Make executable
    file(CHMOD ${output_script}
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
                   GROUP_READ GROUP_EXECUTE
                   WORLD_READ WORLD_EXECUTE
    )
endforeach()

# Configure main trecs script
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/src/trecs.sh
    ${CMAKE_BINARY_DIR}/bin/trecs
    @ONLY
)
file(CHMOD ${CMAKE_BINARY_DIR}/bin/trecs
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
               GROUP_READ GROUP_EXECUTE
               WORLD_READ WORLD_EXECUTE
)

###############################################################################################
# Installation

# Install Fortran executables
install(TARGETS
    trecs_sampler_continuum
    trecs_sampler_hi
    trecs_wrapper
    DESTINATION bin
)

# Install configured Python scripts
install(PROGRAMS
    ${CMAKE_BINARY_DIR}/bin/trecs_xmatch_hi
    ${CMAKE_BINARY_DIR}/bin/trecs_xmatch_clustering
    ${CMAKE_BINARY_DIR}/bin/trecs_addkeys_vizier
    DESTINATION bin
)

# Install main trecs script
install(PROGRAMS
    ${CMAKE_BINARY_DIR}/bin/trecs
    DESTINATION bin
)

# Install example files
install(FILES
    examples/parameter_file.ini
    examples/frequency_list.dat
    examples/make.inc
    DESTINATION share/trecs/examples
)

# Install documentation
install(FILES
    README.md
    INSTALL.md
    LICENSE
    CLAUDE.md
    DESTINATION share/trecs/doc
)

###############################################################################################
# Optional: Create package config

include(CMakePackageConfigHelpers)

# Create version file
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/TRECSConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

# Create config file
configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/TRECSConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/TRECSConfig.cmake"
    INSTALL_DESTINATION lib/cmake/TRECS
)

# Install config files
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/TRECSConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/TRECSConfigVersion.cmake"
    DESTINATION lib/cmake/TRECS
)

###############################################################################################
# Print configuration summary

message(STATUS "")
message(STATUS "T-RECS Configuration Summary:")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  Fortran compiler: ${CMAKE_Fortran_COMPILER}")
message(STATUS "  OpenMP support: ${OpenMP_FOUND}")
message(STATUS "  GSL found: ${GSL_FOUND}")
message(STATUS "  CFITSIO library: ${CFITSIO_LIBRARY}")
message(STATUS "  HEALPIX library: ${HEALPIX_LIBRARY}")
message(STATUS "  LAPACK found: ${LAPACK_FOUND}")
message(STATUS "  Python interpreter: ${Python3_EXECUTABLE}")
message(STATUS "")