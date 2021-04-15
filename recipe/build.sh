#!/bin/bash
set -x

# Manually set the deployment_target
# May not be very important but nice to do
OLDVERSIONMACOS='${MACOSX_VERSION}'
sed -i -e "s@${OLDVERSIONMACOS}@${MACOSX_DEPLOYMENT_TARGET}@g" \
    root-source/cmake/modules/SetUpMacOS.cmake

declare -a CMAKE_PLATFORM_FLAGS

if [[ "${target_platform}" == "osx-arm64" ]]; then
    CONDA_SUBDIR=${target_platform} conda create --prefix "${SRC_DIR}/clang_env" --yes \
        "llvm 9.0.1" "llvmdev 9.0.1" "clangdev 9.0.1 root_62400*"
    Clang_DIR=${SRC_DIR}/clang_env
    CMAKE_PLATFORM_FLAGS+=("-DLLVM_CMAKE_PATH=${SRC_DIR}/clang_env/lib/cmake")
else
    Clang_DIR=${PREFIX}
fi

if [ "$(uname)" == "Linux" ]; then
    INSTALL_SYSROOT=$(python -c "import os; rel = os.path.relpath('$CONDA_BUILD_SYSROOT', '$CONDA_PREFIX'); assert not rel.startswith('.'); print(os.path.join('$PREFIX', rel))")
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_AR=${GCC_AR}")
    CMAKE_PLATFORM_FLAGS+=("-DCLANG_DEFAULT_LINKER=${LD_GOLD}")
    CMAKE_PLATFORM_FLAGS+=("-DDEFAULT_SYSROOT=${INSTALL_SYSROOT}")
    CMAKE_PLATFORM_FLAGS+=("-Dx11=ON")
    CMAKE_PLATFORM_FLAGS+=("-DRT_LIBRARY=${INSTALL_SYSROOT}/usr/lib/librt.so")

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
    CMAKE_PLATFORM_FLAGS+=("-DBLA_PREFER_PKGCONFIG=ON")

    if [ "${ROOT_CONDA_BUILTIN_CLANG-}" != "1" ]; then
        # HACK: Fix LLVM headers for Clang 8's C++17 mode
        sed -i.bak -E 's#std::pointer_to_unary_function<(const )?Value \*, (const )?BasicBlock \*>#\1BasicBlock *(*)(\2Value *)#g' \
            "${Clang_DIR}/include/llvm/IR/Instructions.h"
    fi

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

# The cross-linux toolchain breaks find_file relative to the current file
# Patch up with sed
sed -i -E 's#(ROOT_TEST_DRIVER RootTestDriver.cmake PATHS \$\{THISDIR\} \$\{CMAKE_MODULE_PATH\} NO_DEFAULT_PATH)#\1 CMAKE_FIND_ROOT_PATH_BOTH#g' \
    ../root-source/cmake/modules/RootNewMacros.cmake

# The basics
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
# CMAKE_PLATFORM_FLAGS+=("-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_NAME_DIR=${PREFIX}/lib")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_PREFIX=${PREFIX}")
# CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON")
# CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_RPATH=${PREFIX}/lib")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_PREFIX_PATH=${PREFIX}")

CMAKE_PLATFORM_FLAGS+=("-Dfail-on-missing=ON")
# TODO: Switch this on?
CMAKE_PLATFORM_FLAGS+=("-Dgnuinstall=OFF")
CMAKE_PLATFORM_FLAGS+=("-Drpath=ON")
CMAKE_PLATFORM_FLAGS+=("-Dshared=ON")
CMAKE_PLATFORM_FLAGS+=("-Dsoversion=ON")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_CXX_STANDARD=17")
CMAKE_PLATFORM_FLAGS+=("-DTBB_ROOT_DIR=${PREFIX}")

# Disable all of the builtins
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_afterimage=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_cfitsio=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_davix=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_fftw3=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_freetype=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_ftgl=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_gl2ps=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_glew=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_gsl=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_lz4=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_lzma=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_nlohmannjson=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_openssl=OFF")
# TODO: Make external?
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_openui5=ON")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_pcre=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_tbb=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_unuran=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_vc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_vdt=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_veccore=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_xrootd=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_xxhash=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_zlib=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_zstd=OFF")

# Configure LLVM/Clang/Cling
if [ "${ROOT_CONDA_BUILTIN_CLANG-}" = "1" ]; then
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_llvm=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_clang=ON")
else
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_llvm=OFF")
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_clang=OFF")

    CMAKE_PLATFORM_FLAGS+=("-DLLVM_CONFIG=${Clang_DIR}/bin/llvm-config")
    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_cling=ON")
    CMAKE_PLATFORM_FLAGS+=("-DCLING_BUILD_PLUGINS=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dclad=ON")

    # Cling needs some minor patches to the LLVM sources, hackily apply them rather than rebuilding LLVM
    sed -i "s@LLVM_LINK_LLVM_DYLIB yes@LLVM_LINK_LLVM_DYLIB no@g" "${Clang_DIR}/lib/cmake/llvm/LLVMConfig.cmake"
    cd "${Clang_DIR}"
    patch -p1 < "${RECIPE_DIR}/llvm-patches/0001-Fix-the-compilation.patch"
    patch -p1 < "${RECIPE_DIR}/llvm-patches/0002-Make-datamember-protected.patch"
    cd -
fi

# Disable the Python bindings, we will build them in standalone mode
CMAKE_PLATFORM_FLAGS+=("-Dpyroot_legacy=OFF")
if [ "${ROOT_CONDA_BUILTIN_PYROOT-}" = "1" ]; then
    CMAKE_PLATFORM_FLAGS+=("-DPYTHON_EXECUTABLE=${PYTHON}")
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_PYTHONDIR=${SP_DIR}")
    CMAKE_PLATFORM_FLAGS+=("-Dpyroot=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dtmva-pymva=ON")
else
    CMAKE_PLATFORM_FLAGS+=("-DPYTHON_EXECUTABLE=${PYTHON}")
    CMAKE_PLATFORM_FLAGS+=("-Dpyroot=OFF")
    CMAKE_PLATFORM_FLAGS+=("-Dtmva-pymva=OFF")
fi

# Disable the R bindings, should be made standalong like PyROOT
CMAKE_PLATFORM_FLAGS+=("-Dr=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dtmva-rmva=OFF")

# TMVA, the GPU part should be made standalone like PyROOT
CMAKE_PLATFORM_FLAGS+=("-Dtmva=ON")
CMAKE_PLATFORM_FLAGS+=("-Dtmva-cpu=ON")
CMAKE_PLATFORM_FLAGS+=("-Dtmva-gpu=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcuda=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcudnn=OFF")

# Enable other specific features
CMAKE_PLATFORM_FLAGS+=("-Dasimage=ON")
CMAKE_PLATFORM_FLAGS+=("-Ddataframe=ON")
CMAKE_PLATFORM_FLAGS+=("-Ddavix=ON")
CMAKE_PLATFORM_FLAGS+=("-Dexceptions=ON")
CMAKE_PLATFORM_FLAGS+=("-Dfftw3=ON")
CMAKE_PLATFORM_FLAGS+=("-Dfitsio=ON")
CMAKE_PLATFORM_FLAGS+=("-Dgdml=ON")
CMAKE_PLATFORM_FLAGS+=("-Dgviz=ON")
CMAKE_PLATFORM_FLAGS+=("-Dhttp=ON")
CMAKE_PLATFORM_FLAGS+=("-Dimt=ON")
CMAKE_PLATFORM_FLAGS+=("-Dmathmore=ON")
CMAKE_PLATFORM_FLAGS+=("-Dminuit2=ON")
CMAKE_PLATFORM_FLAGS+=("-Dmlp=ON")
CMAKE_PLATFORM_FLAGS+=("-Dopengl=ON")
CMAKE_PLATFORM_FLAGS+=("-Dpythia8=ON")
CMAKE_PLATFORM_FLAGS+=("-Droofit=ON")
CMAKE_PLATFORM_FLAGS+=("-Droot7=ON")
CMAKE_PLATFORM_FLAGS+=("-Dspectrum=ON")
CMAKE_PLATFORM_FLAGS+=("-Dsqlite=ON")
CMAKE_PLATFORM_FLAGS+=("-Dssl=ON")
CMAKE_PLATFORM_FLAGS+=("-Dtbb=ON")
CMAKE_PLATFORM_FLAGS+=("-Dvdt=ON")
CMAKE_PLATFORM_FLAGS+=("-Dwebgui=ON")
CMAKE_PLATFORM_FLAGS+=("-Dxml=ON")
CMAKE_PLATFORM_FLAGS+=("-Dxrootd=ON")

# On by default but disabled
CMAKE_PLATFORM_FLAGS+=("-Dgfal=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dpythia6=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmysql=OFF")
CMAKE_PLATFORM_FLAGS+=("-Doracle=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dpgsql=OFF")

# Disable other specific features
CMAKE_PLATFORM_FLAGS+=("-Dalien=OFF")
CMAKE_PLATFORM_FLAGS+=("-Darrow=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcefweb=OFF")
CMAKE_PLATFORM_FLAGS+=("-Ddcache=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dfcgi=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dfortran=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dgsl_shared=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmacos_native=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmonalisa=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmpi=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dodbc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dpythia6_nolink=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dqt5web=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dshadowpw=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dunuran=OFF")
CMAKE_PLATFORM_FLAGS+=("-During=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dvc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dveccore=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dvecgeom=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dvmc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dxproofd=OFF")

# Developer only options
CMAKE_PLATFORM_FLAGS+=("-Dccache=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcoverage=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dcxxmodules=OFF")
CMAKE_PLATFORM_FLAGS+=("-Ddev=OFF")
CMAKE_PLATFORM_FLAGS+=("-Ddistcc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Djemalloc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dlibcxx=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmemory_termination=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dmemstat=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dtcmalloc=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dtest_distrdf_pyspark=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dwin_broken_tests=OFF")
CMAKE_PLATFORM_FLAGS+=("-Dwinrtdebug=OFF")

# Platform specific options
# Should be disabled for ARM?
# runtime_cxxmodules 	Enable runtime support for C++ modules 	ON

# Configure the tests
if [ "${ROOT_CONDA_RUN_GTESTS-}" = "1" ]; then
    CMAKE_PLATFORM_FLAGS+=("-Dtesting=ON")
    # Required for the tests to work correctly
    export LD_LIBRARY_PATH=$PREFIX/lib
else
    CMAKE_PLATFORM_FLAGS+=("-Dtesting=OFF")
fi
CMAKE_PLATFORM_FLAGS+=("-Droottest=OFF")

# Now we can actually run CMake
cmake "${CMAKE_PLATFORM_FLAGS[@]}" ../root-source

make "-j${CPU_COUNT}"

if [ "${ROOT_CONDA_RUN_GTESTS-}" = "1" ]; then
    # Run gtests, never fail as Jenkins will check the test results instead
    ctest "-j${CPU_COUNT}" -T test --no-compress-output \
        --exclude-regex '^(pyunittests-pyroot-numbadeclare|test-periodic-build|tutorial-pyroot-pyroot004_NumbaDeclare-py)$' \
        || true
    rm -rf "${HOME}/feedstock_root/Testing"
    cp -rp "Testing" "${HOME}/feedstock_root/"
fi

# cd ../..
# # TODO: Remove
# cp -rp $PWD $PWD.bak
# cd -
# make install

# # Remove thisroot.*
# test "$(ls "${PREFIX}"/bin/thisroot.* | wc -l) = 3"
# rm "${PREFIX}"/bin/thisroot.*
# for suffix in sh csh fish; do
#     cp "${RECIPE_DIR}/thisroot" "${PREFIX}/bin/thisroot.${suffix}"
#     chmod +x "${PREFIX}/bin/thisroot.${suffix}"
# done

# # Symlink the python components in to the site packages directory
# mkdir -p "${SP_DIR}"
# ln -s "${PREFIX}/lib/JupyROOT/" "${SP_DIR}/"
# ln -s "${PREFIX}/lib/ROOT/" "${SP_DIR}/"
# ln -s "${PREFIX}/lib/cppyy/" "${SP_DIR}/"
# ln -s "${PREFIX}/lib/cppyy_backend/" "${SP_DIR}/"
# ln -s "${PREFIX}/lib/JsMVA/" "${SP_DIR}/"
# ln -s "${PREFIX}/lib/cmdLineUtils.py" "${SP_DIR}/"
# ln -s "${PREFIX}/lib"/libJupyROOT*.so "${SP_DIR}/"
# ln -s "${PREFIX}/lib"/libROOTPythonizations*.so "${SP_DIR}/"
# ln -s "${PREFIX}/lib"/libcppyy*.so "${SP_DIR}/"
# # Check PyROOT is roughly working
# # Skip on osx-arm64 as the binaries haven't been signed yet
# if [[ "${target_platform}" != "osx-arm64" ]]; then
#     python -c "import ROOT"
# fi

# # Add the kernel for normal Jupyter
# mkdir -p "${PREFIX}/share/jupyter/kernels/"
# cp -r "${PREFIX}/etc/notebook/kernels/root" "${PREFIX}/share/jupyter/kernels/"
# # Create the config file for normal jupyter (lab|notebook)
# mkdir -p "${PREFIX}/etc/jupyter/"
# cp "${PREFIX}/etc/notebook/jupyter_notebook_config.py" "${PREFIX}/etc/jupyter/jupyter_notebook_config.py"

# # Add the post activate/deactivate scripts
# mkdir -p "${PREFIX}/etc/conda/activate.d"
# cp "${RECIPE_DIR}/activate.sh" "${PREFIX}/etc/conda/activate.d/activate-root.sh"
# cp "${RECIPE_DIR}/activate.csh" "${PREFIX}/etc/conda/activate.d/activate-root.csh"
# cp "${RECIPE_DIR}/activate.fish" "${PREFIX}/etc/conda/activate.d/activate-root.fish"

# mkdir -p "${PREFIX}/etc/conda/deactivate.d"
# cp "${RECIPE_DIR}/deactivate.sh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.sh"
# cp "${RECIPE_DIR}/deactivate.csh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.csh"
# cp "${RECIPE_DIR}/deactivate.fish" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.fish"

# # Revert the HACK
# if [ "$(uname)" != "Linux" ]; then
#     mv "${Clang_DIR}/include/llvm/IR/Instructions.h.bak" "${Clang_DIR}/include/llvm/IR/Instructions.h"
# fi

# # Clean up to minimise disk usage
# # cd ..
# # rm -rf build-dir
