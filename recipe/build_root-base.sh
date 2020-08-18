#!/bin/bash
set -ex

# Manually set the deployment_target
# May not be very important but nice to do
OLDVERSIONMACOS='${MACOSX_VERSION}'
sed -i -e "s@${OLDVERSIONMACOS}@${MACOSX_DEPLOYMENT_TARGET}@g" \
    root-source/cmake/modules/SetUpMacOS.cmake

declare -a CMAKE_PLATFORM_FLAGS
if [ "$(uname)" == "Linux" ]; then
    INSTALL_SYSROOT=$(python -c "import os; rel = os.path.relpath('$CONDA_BUILD_SYSROOT', '$CONDA_PREFIX'); assert not rel.startswith('.'); print(os.path.join('$PREFIX', rel))")
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_AR=${GCC_AR}")
    CMAKE_PLATFORM_FLAGS+=("-DCLANG_DEFAULT_LINKER=${LD_GOLD}")
    CMAKE_PLATFORM_FLAGS+=("-DDEFAULT_SYSROOT=${INSTALL_SYSROOT}")
    CMAKE_PLATFORM_FLAGS+=("-Dx11=ON")
    CMAKE_PLATFORM_FLAGS+=("-DRT_LIBRARY=${INSTALL_SYSROOT}/usr/lib/librt.so")

    # Fix up CMake for using conda's sysroot
    # See https://docs.conda.io/projects/conda-build/en/latest/resources/compiler-tools.html?highlight=cmake#an-aside-on-cmake-and-sysroots
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_TOOLCHAIN_FILE=${RECIPE_DIR}/cross-linux.cmake")

    # Fix finding X11 with CMake, copied from below with minor modifications
    # https://github.com/Kitware/CMake/blob/e59e17c1c7059b7d0f02d6b12bc3094a2afee778/Modules/FindX11.cmake
    cp "${RECIPE_DIR}/FindX11.cmake" "root-source/cmake/modules/"

    # Hide symbols from LLVM/clang to avoid conflicts with other libraries
    for lib_name in $(ls "${PREFIX}/lib" | grep -E 'lib(LLVM|clang).*\.a'); do
        export CXXFLAGS="${CXXFLAGS} -Wl,--exclude-libs,${lib_name}"
    done
    echo "CXXFLAGS is now '${CXXFLAGS}'"
else
    CMAKE_PLATFORM_FLAGS+=("-Dcocoa=ON")
    CMAKE_PLATFORM_FLAGS+=("-DCLANG_RESOURCE_DIR_VERSION='5.0.0'")
    CMAKE_PLATFORM_FLAGS+=("-DBLA_PREFER_PKGCONFIG=ON")

    # HACK: Fix LLVM headers for Clang 8's C++17 mode
    sed -i.bak -E 's#std::pointer_to_unary_function<(const )?Value \*, (const )?BasicBlock \*>#\1BasicBlock *(*)(\2Value *)#g' \
        "${PREFIX}/include/llvm/IR/Instructions.h"

    # HACK: Hack the macOS SDK to make rootcling find the correct ncurses
    if [[ -f  "$CONDA_BUILD_SYSROOT/usr/include/module.modulemap.bak" ]]; then
        echo "ERROR: Looks like the macOS SDK hack has already been applied"
        exit 1
    else
        sed -i.bak "s@\"ncurses.h\"@\"${PREFIX}/include/ncurses.h\"@g" "${CONDA_BUILD_SYSROOT}/usr/include/module.modulemap"
    fi
fi

export CFLAGS="${CFLAGS//-isystem /-I}"
export CPPFLAGS="${CPPFLAGS//-isystem /-I}"
export CXXFLAGS="${CXXFLAGS//-isystem /-I}"
export DEBUG_CFLAGS="${DEBUG_CFLAGS//-isystem /-I}"
export DEBUG_CXXFLAGS="${DEBUG_CXXFLAGS//-isystem /-I}"
export DEBUG_FFLAGS="${DEBUG_FFLAGS//-isystem /-I}"
export DEBUG_FORTRANFLAGS="${DEBUG_FORTRANFLAGS//-isystem /-I}"
export FFLAGS="${FFLAGS//-isystem /-I}"
export FORTRANFLAGS="${FORTRANFLAGS//-isystem /-I}"

mkdir -p build-dir
cd build-dir

# Remove -std=c++XX from build ${CXXFLAGS}
CXXFLAGS=$(echo "${CXXFLAGS}" | sed -E 's@-std=c\+\+[^ ]+@@g')
export CXXFLAGS

# Enable ccache if requested
if [ -n "${ROOT_CONDA_USE_CCACHE+x}" ]; then
    export CCACHE_DIR=${HOME}/feedstock_root/ccache/
    CCACHE_BASEDIR=$(cd "${PWD}/.."; pwd)
    export CCACHE_BASEDIR
    echo "Enabling ccache with CCACHE_BASEDIR=$CCACHE_BASEDIR"
    CMAKE_PLATFORM_FLAGS+=("-Dccache=ON")
fi

# The cross-linux toolchain breaks find_file relative to the current file
# Patch up with sed
sed -i -E 's#(ROOT_TEST_DRIVER RootTestDriver.cmake PATHS \$\{THISDIR\} \$\{CMAKE_MODULE_PATH\} NO_DEFAULT_PATH)#\1 CMAKE_FIND_ROOT_PATH_BOTH#g' \
    ../root-source/cmake/modules/RootNewMacros.cmake

if [ -n "${ROOT_CONDA_RUN_GTESTS+x}" ]; then
    # Required for the tests to work correctly
    export LD_LIBRARY_PATH=$PREFIX/lib
fi

cmake -LAH \
    "${CMAKE_PLATFORM_FLAGS[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="${PREFIX}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_RPATH="${PREFIX}/lib" \
    -DCMAKE_INSTALL_NAME_DIR="${PREFIX}/lib" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
    -DCLING_BUILD_PLUGINS=OFF \
    -DPYTHON_EXECUTABLE="${PYTHON}" \
    -DTBB_ROOT_DIR="${PREFIX}" \
    -Dexplicitlink=ON \
    -Dexceptions=ON \
    -Dfail-on-missing=ON \
    -Dgnuinstall=OFF \
    -Dshared=ON \
    -Dsoversion=ON \
    -Dbuiltin_afterimage=OFF \
    -Dbuiltin_clang=OFF \
    -Dbuiltin_davix=OFF \
    -Dbuiltin_ftgl=OFF \
    -Dbuiltin_gl2ps=OFF \
    -Dbuiltin_glew=OFF \
    -Dbuiltin_llvm=OFF \
    -Dbuiltin_xrootd=OFF \
    -Dbuiltin_zlib=OFF \
    -Drpath=ON \
    -DCMAKE_CXX_STANDARD=17 \
    -Dminuit2=ON \
    -Dgviz=ON \
    -Droofit=ON \
    -Dtbb=ON \
    -Dcastor=OFF \
    -Dgfal=OFF \
    -Dmysql=OFF \
    -Dopengl=ON \
    -Doracle=OFF \
    -Dpgsql=OFF \
    -Dpythia6=OFF \
    -Dpythia8=ON \
    -Dtesting=ON \
    -Droottest=OFF \
    -Droot7=ON \
    -Dr=ON \
    ../root-source

make "-j${CPU_COUNT}"

if [ -n "${ROOT_CONDA_RUN_GTESTS+x}" ]; then
    # Run gtests, never fail as Jenkins will check the test results instead
    ctest "-j${CPU_COUNT}" -T test --no-compress-output \
        --exclude-regex '^(pyunittests-pyroot-numbadeclare|test-periodic-build|tutorial-pyroot-pyroot004_NumbaDeclare-py)$' \
        || true
    rm -rf "${HOME}/feedstock_root/Testing"
    cp -rp "Testing" "${HOME}/feedstock_root/"
fi

make install "-j${CPU_COUNT}"

# Remove thisroot.*
test "$(ls "${PREFIX}"/bin/thisroot.* | wc -l) = 3"
rm "${PREFIX}"/bin/thisroot.*
for suffix in sh csh fish; do
    cp "${RECIPE_DIR}/thisroot" "${PREFIX}/bin/thisroot.${suffix}"
    chmod +x "${PREFIX}/bin/thisroot.${suffix}"
done

# Symlink the python components in to the site packages directory
mkdir -p "${SP_DIR}"
ln -s "${PREFIX}/lib/JupyROOT/" "${SP_DIR}/"
ln -s "${PREFIX}/lib/ROOT/" "${SP_DIR}/"
ln -s "${PREFIX}/lib/cppyy/" "${SP_DIR}/"
ln -s "${PREFIX}/lib/cppyy_backend/" "${SP_DIR}/"
ln -s "${PREFIX}/lib/JsMVA/" "${SP_DIR}/"
ln -s "${PREFIX}/lib/cmdLineUtils.py" "${SP_DIR}/"
ln -s "${PREFIX}/lib"/libJupyROOT*.so "${SP_DIR}/"
ln -s "${PREFIX}/lib"/libROOTPythonizations*.so "${SP_DIR}/"
ln -s "${PREFIX}/lib"/libcppyy*.so "${SP_DIR}/"
# Check PyROOT is roughly working
python -c "import ROOT"

# Add the kernel for normal Jupyter
mkdir -p "${PREFIX}/share/jupyter/kernels/"
cp -r "${PREFIX}/etc/notebook/kernels/root" "${PREFIX}/share/jupyter/kernels/"
# Create the config file for normal jupyter (lab|notebook)
mkdir -p "${PREFIX}/etc/jupyter/"
cp "${PREFIX}/etc/notebook/jupyter_notebook_config.py" "${PREFIX}/etc/jupyter/jupyter_notebook_config.py"

# Add the post activate/deactivate scripts
mkdir -p "${PREFIX}/etc/conda/activate.d"
cp "${RECIPE_DIR}/activate.sh" "${PREFIX}/etc/conda/activate.d/activate-root.sh"
cp "${RECIPE_DIR}/activate.csh" "${PREFIX}/etc/conda/activate.d/activate-root.csh"
cp "${RECIPE_DIR}/activate.fish" "${PREFIX}/etc/conda/activate.d/activate-root.fish"

mkdir -p "${PREFIX}/etc/conda/deactivate.d"
cp "${RECIPE_DIR}/deactivate.sh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.sh"
cp "${RECIPE_DIR}/deactivate.csh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.csh"
cp "${RECIPE_DIR}/deactivate.fish" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.fish"

# Revert the HACK
if [ "$(uname)" != "Linux" ]; then
    mv "${PREFIX}/include/llvm/IR/Instructions.h.bak" "${PREFIX}/include/llvm/IR/Instructions.h"
fi

# Clean up to minimise disk usage
cd ..
rm -rf build-dir
