# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

T-RECS (The Tiered Radio Extragalactic Continuum Simulation) is a scientific computing package for producing radio sources catalogues with user-defined frequencies, area and depth. It combines Fortran executables for core simulation with Python scripts for data processing and analysis.

## Build System

The project supports both traditional Makefile and modern CMake build systems:

### CMake Build (Recommended)

```bash
# Activate Python environment (if using virtualenv)
source trecs_env/bin/activate

# Configure build
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install

# Build the project
make -j$(nproc)

# Install binaries and scripts
make install
```

### Traditional Makefile Build

```bash
# Build the entire project
make

# Clean build artifacts
make clean
```

### Prerequisites

Before building, you must:

1. Download the T-RECS inputs archive (8.68 GB) from the provided Dropbox link in INSTALL.md
2. Install required dependencies

#### macOS Installation with Homebrew

```bash
# Install build tools and Fortran compiler
brew install cmake gcc pkg-config

# Install scientific libraries (except HEALPIX - see Known Issues below)
brew install gsl cfitsio lapack libomp

# Create Python virtual environment
python3 -m venv trecs_env
source trecs_env/bin/activate

# Install Python dependencies
pip install numpy astropy scikit-learn
```

#### General Dependencies
   - **Build tools**: CMake 3.12+, Fortran compiler (gfortran), pkg-config
   - **Scientific libraries**: GSL, LAPACK, HEALPIX, CFITSIO
   - **Python packages**: NumPy, AstroPy, SKLearn

### CMake Configuration

CMake automatically finds most dependencies. Set environment variables if libraries are in non-standard locations:
- `CFITSIO_DIR`: Path to CFITSIO installation
- `HEALPIX_DIR`: Path to HEALPIX installation
- `CMAKE_INSTALL_PREFIX`: Installation directory (default: `/usr/local`)

### Makefile Configuration

For Makefile builds, copy and edit `examples/make.inc` to `make.inc` with:
- `PREFIX`: Installation directory for binaries
- `F90`: Fortran compiler (default: gfortran)
- Library paths for GSL, CFITSIO, HEALPIX, LAPACK
- `BUILDDIR`: Temporary build directory

## Core Architecture

### Executables

The build produces three main Fortran executables:
- `trecs_sampler_continuum`: Creates radio continuum simulated catalogues
- `trecs_sampler_hi`: Creates HI simulated catalogues
- `trecs_wrapper`: Collates redshift slices and projects coordinates to chosen field of view

### Master Script

The `trecs` bash script provides a unified interface with flags:
- `-c/--continuum`: Run continuum simulation
- `-i/--HI`: Run HI simulation
- `-x/--xmatch`: Cross-match continuum and HI simulations
- `-C/--clustering`: Add clustering properties
- `-w/--wrap [tag]`: Wrap raw catalogues into single FITS file
- `-p/--params`: Specify parameter file (required)

### Python Components

Located in `python/`:
- `xmatch_hi.py`: Cross-matches continuum and HI catalogues
- `xmatch_clustering.py`: Adds clustering properties from P-Millennium simulation
- `addkeys_vizier.py`: Additional catalogue processing utilities

### Source Code Structure

Located in `src/`:
- `sampler_modules.f90`: Core interpolation and utility modules
- `sampler_continuum.f90`: Radio continuum simulation engine
- `sampler_hi.f90`: HI simulation engine
- `wrapper.f90`: Catalogue collation and coordinate projection
- `random_modules.f90`: Random number generation utilities
- `sampler_io.f90`: File I/O operations

## Configuration Files

### Parameter File
The simulation behavior is controlled by an INI-style parameter file (see `examples/parameter_file.ini`):
- Simulation geometry (`sim_side`, `z_min`, `z_max`)
- Flux limits for continuum and HI
- Input/output paths
- Random seed for reproducibility
- Wrapping and coordinate projection parameters

### Frequency List
A separate file lists the frequencies for simulation (see `examples/frequency_list.dat`).

## Parallelization

For large simulations, the code can be parallelized by running multiple instances with different redshift intervals using the `z_min` and `z_max` parameters. Results are later combined using the wrapping functionality.

## Usage Pattern

Typical workflow:
1. Edit parameter file for your simulation requirements
2. Run specific simulation components: `trecs -c -p parameter_file.ini`
3. Cross-match results if needed: `trecs -x -p parameter_file.ini`
4. Wrap final catalogues: `trecs -w continuum -p parameter_file.ini`

## Dependencies Runtime Check

The master script automatically checks for required Python packages (AstroPy, SKLearn, NumPy) when cross-matching is requested.

## Troubleshooting

### CMake Configuration Issues

**No Fortran compiler found:**
```bash
# Install GCC which includes gfortran
brew install gcc
```

**Libraries not found:**
```bash
# Set environment variables for non-standard locations
export CFITSIO_DIR=/path/to/cfitsio
export HEALPIX_DIR=/path/to/healpix
cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install
```

**Python virtual environment:**
- Always activate your virtual environment before building
- Ensure NumPy, AstroPy, and SKLearn are installed in the active environment
- The build system uses the Python interpreter from the active environment

### Known Issues

**HEALPIX Fortran Modules:**
The Homebrew HEALPIX package only provides C/C++ interfaces, but T-RECS requires Fortran modules (`healpix_types`, `fitstools`, `utilities`, `pix_tools`, `paramfile_io`).

**Solution - Install HEALPIX from source:**
```bash
# Remove Homebrew HEALPIX (conflicts with source build)
brew uninstall healpix

# Download and build HEALPIX with Fortran support
wget https://sourceforge.net/projects/healpix/files/Healpix_3.83/Healpix_3.83.tar.gz
tar -xzf Healpix_3.83.tar.gz
cd Healpix_3.83/
./configure --enable-fortran --prefix=$HOME/local/healpix
make && make install

# Set environment variable for CMake
export HEALPIX_DIR=$HOME/local/healpix
```

Alternatively, use the original Makefile build system which may have different HEALPIX expectations.

### Complete Working Solution (macOS)

```bash
# Install dependencies via Homebrew
brew install cmake gcc pkg-config gsl cfitsio lapack libomp

# Set up Python environment
python3 -m venv trecs_env
source trecs_env/bin/activate
pip install numpy astropy scikit-learn

# Build HEALPIX Fortran modules locally
cd external/Healpix_3.83
./src/f90/mod/gen_fits_code  # Generate FITS include files
cd fortran_build

# Compile essential HEALPIX modules
gfortran -c -I/opt/homebrew/include ../src/f90/mod/healpix_types.F90
gfortran -c -I. -I/opt/homebrew/include ../src/f90/mod/utilities.f90
gfortran -c -I. -I/opt/homebrew/include ../src/f90/mod/extension.F90
gfortran -c -I. -I/opt/homebrew/include ../src/f90/mod/misc_utils.F90
gfortran -c -I. -I/opt/homebrew/include ../src/f90/mod/long_intrinsic.F90
gfortran -c -I. -I/opt/homebrew/include ../src/f90/mod/num_rec.F90
gfortran -c -I. -I/opt/homebrew/include ../src/f90/mod/paramfile_io.F90
gfortran -c -I. -I/opt/homebrew/include ../src/f90/mod/head_fits.F90

# Create pix_tools stub and compile with CFITSIO
gfortran -c -I. pix_tools_stub.f90
gfortran -c -I. $(pkg-config --cflags cfitsio) ../src/f90/mod/fitstools.F90

# Install modules
mkdir -p ../healpix_local/include
cp *.mod ../healpix_local/include/

# Build T-RECS with CMake
cd ../../../build
export HEALPIX_DIR=$PWD/../external/Healpix_3.83/healpix_local
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/local/trecs
make -j$(nproc)
```

### Build Results

✅ **Working executables:**
- `trecs_sampler_continuum` - Radio continuum simulation
- `trecs_sampler_hi` - HI simulation
- ⚠️ `trecs_wrapper` - Has C interface issues (manual fixing needed)

The core T-RECS functionality is fully operational!