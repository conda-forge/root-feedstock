#!/bin/bash
set -e

# Backup method of sed required on macOS, and supported on linux.

# Fixed in 6.16.02
# Fix for missing libraries. CMake > 3.10 doesn't need LIBXML2_INCLUDE_DIR
sed -i.bak -e 's@include_directories(${LIBXML2_INCLUDE_DIR})@include_directories(${LIBXML2_INCLUDE_DIR} ${LIBXML2_INCLUDE_DIRS})@g' \
    root-source/io/xmlparser/CMakeLists.txt && rm $_.bak

# Fixed in 6.16.02
# Fix ROOT includes on case-insensitive file systems
sed -i.bak -e 's@<ROOT/RConfig.h>@"ROOT/RConfig.h"@g' \
    root-source/core/base/inc/RConfig.h && rm $_.bak

# Remove the library path muddling that `root` tries to do
sed -i.bak -e 's@SetLibraryPath();@@g' \
    root-source/rootx/src/rootx.cxx && rm $_.bak

# Manually set the deployment_target
# May not be very important but nice to do
OLDVERSIONMACOS='${MACOSX_VERSION}'
sed -i.bak -e "s@${OLDVERSIONMACOS}@${MACOSX_DEPLOYMENT_TARGET}@g" \
    root-source/cmake/modules/SetUpMacOS.cmake && rm $_.bak

# This is part of CMake, and is manually removed for a better link
# May not be needed, but nice to do
# Is in a current PR to ROOT: #3397
rm root-source/cmake/modules/FindGSL.cmake

mkdir -p build-dir
cd build-dir

if [ "$(uname)" == "Linux" ]; then
    cmake_args="-DCMAKE_TOOLCHAIN_FILE=${RECIPE_DIR}/toolchain.cmake -DCMAKE_AR=${GCC_AR} -DCLANG_DEFAULT_LINKER=${LD_GOLD} -DDEFAULT_SYSROOT=${PREFIX}/${HOST}/sysroot -Dx11=ON -DRT_LIBRARY=${PREFIX}/${HOST}/sysroot/usr/lib/librt.so"
else
    cmake_args="-Dcocoa=ON -DCLANG_RESOURCE_DIR_VERSION='5.0.0'"
    echo "SDKROOT is: '${SDKROOT}'"
    echo "CONDA_BUILD_SYSROOT is: '${CONDA_BUILD_SYSROOT}'"
    export SDKROOT="${CONDA_BUILD_SYSROOT}"

    # This is a patch for the macOS needing to be unlinked
    # Not solved in ROOT yet.
    PYLIBNAME=$(python -c 'import sysconfig; print("libpython" + sysconfig.get_config_var("VERSION") + (sysconfig.get_config_var("ABIFLAGS") or sysconfig.get_config_var("abiflags") or ""))')
    sed -i.bak -e "s@// load any dependent libraries@if(moduleBasename.Contains(\"PyROOT\") || moduleBasename.Contains(\"PyMVA\")) gSystem->Load(\"${PYLIBNAME}\");@g" \
        root-source/core/base/src/TSystem.cxx && rm $_.bak
fi

CXXFLAGS=$(echo "${CXXFLAGS}" | echo "${CXXFLAGS}" | sed -E 's@-std=c\+\+[^ ]+@@g')
export CXXFLAGS

cmake -LAH \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH="${PREFIX}" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_RPATH="${PREFIX}/lib" \
    -DCMAKE_INSTALL_NAME_DIR="${PREFIX}/lib" \
    -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
    ${cmake_args} \
    -DCMAKE_C_COMPILER="${GCC}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_COMPILER="${GXX}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCLING_BUILD_PLUGINS=OFF \
    -DPYTHON_EXECUTABLE=${PYTHON} \
    -Dexplicitlink=ON \
    -Dexceptions=ON \
    -Dfail-on-missing=ON \
    -Dgnuinstall=OFF \
    -Dshared=ON \
    -Dsoversion=ON \
    -Dbuiltin_clang=OFF \
    -Dbuiltin_glew=OFF \
    -Dbuiltin_xrootd=OFF \
    -Dbuiltin_davix=OFF \
    -Dbuiltin_llvm=OFF \
    -Dbuiltin_afterimage=OFF \
    -Drpath=ON \
    -Dcxx11=OFF \
    -Dcxx14=OFF \
    -Dcxx17=ON \
    -Dminuit2=ON \
    -Dgviz=OFF \
    -Droofit=ON \
    -Dtbb=ON \
    -Dcastor=OFF \
    -Dgfal=OFF \
    -Dmysql=OFF \
    -Dopengl=OFF \
    -Doracle=OFF \
    -Dpgsql=OFF \
    -Dpythia6=OFF \
    -Dpythia8=ON \
    -Dtesting=ON \
    -Droottest=OFF \
    ../root-source

make -j${CPU_COUNT}
make install

# Create symlinks so conda can find the Python bindings
test "$(ls "${PREFIX}"/lib/*.py | wc -l) = 4"
ln -s "${PREFIX}/lib/ROOT.py" "${SP_DIR}/"
ln -s "${PREFIX}/lib/_pythonization.py" "${SP_DIR}/"
ln -s "${PREFIX}/lib/cmdLineUtils.py" "${SP_DIR}/"
ln -s "${PREFIX}/lib/cppyy.py" "${SP_DIR}/"

test "$(ls "${PREFIX}"/lib/*/__init__.py | wc -l) = 2"
ln -s "${PREFIX}/lib/JsMVA/" "${SP_DIR}/"
ln -s "${PREFIX}/lib/JupyROOT/" "${SP_DIR}/"

test "$(ls "${PREFIX}"/lib/libPy* | wc -l) = 2"
ln -s "${PREFIX}/lib/libPyROOT.so" "${SP_DIR}/"
ln -s "${PREFIX}/lib/libPyMVA.so" "${SP_DIR}/"
ln -s "${PREFIX}/lib/libJupyROOT.so" "${SP_DIR}/"

# Remove the PCH as we will regenerate in the post install hook
rm "${PREFIX}/etc/allDict.cxx.pch"

# Add the post activate/deactivate scripts
mkdir -p "${PREFIX}/etc/conda/activate.d"
cp "${RECIPE_DIR}/activate.sh" "${PREFIX}/etc/conda/activate.d/activate-root.sh"
cp "${RECIPE_DIR}/activate.csh" "${PREFIX}/etc/conda/activate.d/activate-root.csh"
cp "${RECIPE_DIR}/activate.fish" "${PREFIX}/etc/conda/activate.d/activate-root.fish"

mkdir -p "${PREFIX}/etc/conda/deactivate.d"
cp "${RECIPE_DIR}/deactivate.sh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.sh"
cp "${RECIPE_DIR}/deactivate.csh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.csh"
cp "${RECIPE_DIR}/deactivate.fish" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.fish"
