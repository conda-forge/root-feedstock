#!/bin/bash
set -x

if command -v sccache &> /dev/null; then
    export CMAKE_C_COMPILER_LAUNCHER=sccache
    export CMAKE_CXX_COMPILER_LAUNCHER=sccache
else
    echo "Disabling sccache as it is not available"
fi

if [[ "${target_platform}" == "linux-"* ]]; then
  # Conda's binary relocation can result in string changing which can result in errors like
  #   > $ root.exe -l -b -q -x root-feedstock/recipe/test.cpp++
  #   > powerpc64le-conda-linux-gnu-c++: error: missing filename after '-o'
  # https://gitter.im/conda-forge/conda-forge.github.io?at=61e18f469a3354540621b912
  export CXXFLAGS="${CXXFLAGS} -fno-merge-constants"
  export CFLAGS="${CFLAGS} -fno-merge-constants"
fi

# https://github.com/conda-forge/root-feedstock/issues/160
export CXXFLAGS="${CXXFLAGS} -D__ROOFIT_NOBANNER"

if [[ "${target_platform}" == "linux-ppc64le" ]]; then
  export CXXFLAGS="${CXXFLAGS} -fplt"
  export CFLAGS="${CFLAGS} -fplt"
fi

# Manually set the deployment_target
# May not be very important but nice to do
OLDVERSIONMACOS='${MACOSX_VERSION}'
sed -i -e "s@${OLDVERSIONMACOS}@${MACOSX_DEPLOYMENT_TARGET}@g" \
    root-source/cmake/modules/SetUpMacOS.cmake

declare -a CMAKE_PLATFORM_FLAGS

if [[ "${target_platform}" != "${build_platform}" && "${target_platform}" == osx* ]]; then
    CONDA_SUBDIR=${target_platform} conda create --prefix "${SRC_DIR}/clang_env" --yes \
        "llvm ${clang_version}" "clangdev ${clang_version} ${clang_patches_version}*"
    Clang_DIR=${SRC_DIR}/clang_env
    CMAKE_PLATFORM_FLAGS+=("-DLLVM_CMAKE_PATH=${SRC_DIR}/clang_env/lib/cmake")

    CONDA_SUBDIR=${build_platform} conda create --prefix "${SRC_DIR}/clang_env_build" --yes \
        "llvm ${clang_version}" "clangdev ${clang_version} ${clang_patches_version}*"
    Clang_DIR_BUILD=${SRC_DIR}/clang_env_build
else
    Clang_DIR=${PREFIX}
    Clang_DIR_BUILD=${BUILD_PREFIX}
fi

if [[ "${target_platform}" == linux* ]]; then
    rel=$(realpath --relative-to="$CONDA_PREFIX" "$CONDA_BUILD_SYSROOT")
    if [[ $rel == .* ]]; then
        echo "Error: Relative path starts with '.'"
        exit 1
    fi
    INSTALL_SYSROOT="$PREFIX/$rel"
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_AR=${GCC_AR}")
    CMAKE_PLATFORM_FLAGS+=("-DCLANG_DEFAULT_LINKER=${LD_GOLD}")
    CMAKE_PLATFORM_FLAGS+=("-DDEFAULT_SYSROOT=${INSTALL_SYSROOT}")
    CMAKE_PLATFORM_FLAGS+=("-DRT_LIBRARY=${INSTALL_SYSROOT}/usr/lib/librt.so")

    # Fix finding X11 with CMake, copied from below with minor modifications
    # https://github.com/Kitware/CMake/blob/e59e17c1c7059b7d0f02d6b12bc3094a2afee778/Modules/FindX11.cmake
    cp "${RECIPE_DIR}/FindX11.cmake" "root-source/cmake/modules/"

    # Hide symbols from LLVM/clang to avoid conflicts with other libraries
    set +x
    for lib_name in $(ls "${PREFIX}/lib" | grep -E 'lib(LLVM|clang).*\.a'); do
        export CXXFLAGS="${CXXFLAGS} -Wl,--exclude-libs,${lib_name}"
    done
    set -x
    echo "CXXFLAGS is now '${CXXFLAGS}'"
else
    CMAKE_PLATFORM_FLAGS+=("-DBLA_PREFER_PKGCONFIG=ON")
    clang_version_split=(${clang_version//./ })
    CMAKE_PLATFORM_FLAGS+=("-DCLANG_RESOURCE_DIR_VERSION=${clang_version_split[0]}")

    # HACK: Hack the macOS SDK to make rootcling find the correct ncurses
    if [[ -f  "$CONDA_BUILD_SYSROOT/usr/include/module.modulemap.bak" ]]; then
        echo "ERROR: Looks like the macOS SDK hack has already been applied"
        exit 1
    else
        sed -i.bak "s@\"ncurses.h\"@\"${PREFIX}/include/ncurses.h\"@g" "${CONDA_BUILD_SYSROOT}/usr/include/module.modulemap"
    fi
fi

if [[ "${target_platform}" == osx* ]]; then
    CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
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
    ${SRC_DIR}/root-source/cmake/modules/RootNewMacros.cmake

# The basics
if [ "${ROOT_CONDA_BUILD_TYPE-}" == "" ]; then
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
else
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_BUILD_TYPE=${ROOT_CONDA_BUILD_TYPE}")
fi
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_PREFIX=${PREFIX}")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_PREFIX_PATH=${PREFIX}")

CMAKE_PLATFORM_FLAGS+=("-Dfail-on-missing=ON")
# TODO: Switch this on?
CMAKE_PLATFORM_FLAGS+=("-Dgnuinstall=OFF")
CMAKE_PLATFORM_FLAGS+=("-Drpath=ON")
CMAKE_PLATFORM_FLAGS+=("-Dshared=ON")
CMAKE_PLATFORM_FLAGS+=("-Dsoversion=ON")
CMAKE_PLATFORM_FLAGS+=("-DCMAKE_CXX_STANDARD=${ROOT_CXX_STANDARD}")
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
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_vdt=ON")
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

    if [[ "${target_platform}" == "${build_platform}" ]]; then
        CMAKE_PLATFORM_FLAGS+=("-DLLVM_CONFIG=${Clang_DIR}/bin/llvm-config")
        CMAKE_PLATFORM_FLAGS+=("-DLLVM_TABLEGEN_EXE=${Clang_DIR}/bin/llvm-tblgen")
    else
        CMAKE_PLATFORM_FLAGS+=("-DLLVM_CONFIG=${Clang_DIR_BUILD}/bin/llvm-config")
        CMAKE_PLATFORM_FLAGS+=("-DLLVM_TABLEGEN_EXE=${Clang_DIR_BUILD}/bin/llvm-tblgen")
    fi

    CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_cling=ON")
    CMAKE_PLATFORM_FLAGS+=("-DCLING_BUILD_PLUGINS=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dclad=ON")

    # Cling needs some minor patches to the LLVM sources, hackily apply them rather than rebuilding LLVM
    sed -i "s@LLVM_LINK_LLVM_DYLIB yes@LLVM_LINK_LLVM_DYLIB no@g" "${Clang_DIR}/lib/cmake/llvm/LLVMConfig.cmake"
fi

# Enable some vectorisation options
CMAKE_PLATFORM_FLAGS+=("-Dveccore=ON")
CMAKE_PLATFORM_FLAGS+=("-Dvc=ON")
CMAKE_PLATFORM_FLAGS+=("-Dbuiltin_veccore=ON")

# Cross compilation options
if [[ "${target_platform}" != "${build_platform}" ]]; then
    CMAKE_PLATFORM_FLAGS+=("-Dfound_urandom=ON")

    # Build rootcling_stage1 for the current platform
    cp "${SRC_DIR}/root-source/interpreter/cling/lib/Interpreter/CIFactory.cpp"{,.orig}
    sed -i "s@TODO_OVERRIDE_TARGET@\"--target=${BUILD}\"@g" "${SRC_DIR}/root-source/interpreter/cling/lib/Interpreter/CIFactory.cpp"
    diff "${SRC_DIR}/root-source/interpreter/cling/lib/Interpreter/CIFactory.cpp"{.orig,} || true

    declare -a CMAKE_PLATFORM_FLAGS_BUILD
    CMAKE_PLATFORM_FLAGS_BUILD+=("-Dminimal=ON")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-Dfail-on-missing=ON")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-Drpath=ON")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_BUILD_TYPE=Release")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DLLVM_CONFIG=${Clang_DIR_BUILD}/bin/llvm-config")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DLLVM_TABLEGEN_EXE=${Clang_DIR_BUILD}/bin/llvm-tblgen")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_CXX_STANDARD=${ROOT_CXX_STANDARD}")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DROOT_CLING_TARGET=all")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-GNinja")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-Dfound_urandom=ON")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_C_COMPILER=$CC_FOR_BUILD")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_CXX_COMPILER=$CXX_FOR_BUILD")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-Dbuiltin_llvm=OFF")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-Dbuiltin_clang=OFF")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_C_FLAGS=$(echo $CFLAGS | sed s@$PREFIX@$BUILD_PREFIX@g | sed -E 's/(^| )-m[^=]+=[^ ]+//g')")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_CXX_FLAGS=$(echo $CXXFLAGS | sed s@$PREFIX@$BUILD_PREFIX@g | sed -E 's/(^| )-m[^=]+=[^ ]+//g')")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_EXE_LINKER_FLAGS=$(echo $LDFLAGS | sed s@$PREFIX@$BUILD_PREFIX@g)")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_MODULE_LINKER_FLAGS=$(echo $LDFLAGS | sed s@$PREFIX@$BUILD_PREFIX@g)")
    CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_SHARED_LINKER_FLAGS=$(echo $LDFLAGS | sed s@$PREFIX@$BUILD_PREFIX@g)")

    CONDA_BUILD_SYSROOT_BUILD=$CONDA_BUILD_SYSROOT

    if [[ "${target_platform}" == osx* ]]; then
        CMAKE_PLATFORM_FLAGS_BUILD+=("-DLLVM_CMAKE_PATH=${SRC_DIR}/clang_env_build/lib/cmake")
        clang_version_split=(${clang_version//./ })
        CMAKE_PLATFORM_FLAGS_BUILD+=("-DCLANG_RESOURCE_DIR_VERSION=${clang_version_split[0]}")
        # CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_LINKER=${BUILD_PREFIX}/bin/arm64-apple-darwin20.0.0-ld")
    elif [[ "${target_platform}" == linux* ]]; then
        # CMAKE_PLATFORM_FLAGS_BUILD+=("-DCMAKE_LINKER=${BUILD_PREFIX}/bin/arm64-apple-darwin20.0.0-ld")

        CONDA_BUILD_SYSROOT_BUILD="${BUILD_PREFIX}/${BUILD}/sysroot"
    else
        echo "Unsupported cross-compilation target"
        exit 1
    fi

    CONDA_BUILD_SYSROOT="${CONDA_BUILD_SYSROOT_BUILD}" CMAKE_PREFIX_PATH="${BUILD_PREFIX}" \
        cmake "${SRC_DIR}/root-source" \
                -B "${SRC_DIR}/build-rootcling_stage1-xp" \
                -DCLING_CXX_PATH="$CXX_FOR_BUILD" \
                "${CMAKE_PLATFORM_FLAGS_BUILD[@]}" \
                $(echo $CMAKE_ARGS | sed 's@aarch64@x86_64@g' | sed s@$PREFIX@$BUILD_PREFIX@g)

    CONDA_BUILD_SYSROOT="${CONDA_BUILD_SYSROOT_BUILD}"  \
        cmake --build "${SRC_DIR}/build-rootcling_stage1-xp" --target rootcling_stage1 -- "-j${CPU_COUNT}"

    # Build rootcling for the current platform but that will target the host platform
    cp ${SRC_DIR}/root-source/interpreter/cling/lib/Interpreter/CIFactory.cpp{.orig,}
    sed -i "s@TODO_OVERRIDE_TARGET@\"--target=${HOST}\"@g" ${SRC_DIR}/root-source/interpreter/cling/lib/Interpreter/CIFactory.cpp
    diff ${SRC_DIR}/root-source/interpreter/cling/lib/Interpreter/CIFactory.cpp{.orig,} || true

    CONDA_BUILD_SYSROOT="${CONDA_BUILD_SYSROOT_BUILD}" CMAKE_PREFIX_PATH="${BUILD_PREFIX}" \
        cmake "${SRC_DIR}/root-source" \
                -B "${SRC_DIR}/build-rootcling-xp" \
                -DCLING_CXX_PATH="$CXX" \
                "${CMAKE_PLATFORM_FLAGS_BUILD[@]}" \
                $(echo $CMAKE_ARGS | sed 's@aarch64@x86_64@g' | sed s@$PREFIX@$BUILD_PREFIX@g)

    cmake --build "${SRC_DIR}/build-rootcling-xp" --target rootcling_stage1 -- "-j${CPU_COUNT}"
    mv "${SRC_DIR}/build-rootcling-xp/core/rootcling_stage1/src/rootcling_stage1"{,.orig}
    cp "${SRC_DIR}"/build-{rootcling_stage1,rootcling}-xp/"core/rootcling_stage1/src/rootcling_stage1"
    touch -r "${SRC_DIR}/build-rootcling-xp/core/rootcling_stage1/src/rootcling_stage1"{.orig,}
    cmake --build "${SRC_DIR}/build-rootcling-xp" --target rootcling -- "-j${CPU_COUNT}"
fi

# Disable the Python bindings if we're building them in standalone mode
CMAKE_PLATFORM_FLAGS+=("-Dpyroot_legacy=OFF")
if [ "${ROOT_CONDA_BUILTIN_PYROOT-}" = "true" ]; then
    Python_INCLUDE_DIR="$(python -c 'import sysconfig; print(sysconfig.get_path("include"))')"
    Python_NumPy_INCLUDE_DIR="$(python -c 'import numpy;print(numpy.get_include())')"
    CMAKE_PLATFORM_FLAGS+=("-DPython_EXECUTABLE:PATH=${PYTHON}")
    CMAKE_PLATFORM_FLAGS+=("-DPython_INCLUDE_DIR:PATH=${Python_INCLUDE_DIR}")
    CMAKE_PLATFORM_FLAGS+=("-DPython_NumPy_INCLUDE_DIR=${Python_NumPy_INCLUDE_DIR}")
    CMAKE_PLATFORM_FLAGS+=("-DPython3_EXECUTABLE:PATH=${PYTHON}")
    CMAKE_PLATFORM_FLAGS+=("-DPython3_INCLUDE_DIR:PATH=${Python_INCLUDE_DIR}")
    CMAKE_PLATFORM_FLAGS+=("-DPython3_NumPy_INCLUDE_DIR=${Python_NumPy_INCLUDE_DIR}")
    CMAKE_PLATFORM_FLAGS+=("-DCMAKE_INSTALL_PYTHONDIR=${SP_DIR}")
    CMAKE_PLATFORM_FLAGS+=("-Dpyroot=ON")
    CMAKE_PLATFORM_FLAGS+=("-Dtmva-pymva=ON")
else
    CMAKE_PLATFORM_FLAGS+=("-DPython3_EXECUTABLE=${PYTHON}")
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
CMAKE_PLATFORM_FLAGS+=("-Dfftw3=ON")
CMAKE_PLATFORM_FLAGS+=("-Dfitsio=ON")
CMAKE_PLATFORM_FLAGS+=("-Dgdml=ON")
CMAKE_PLATFORM_FLAGS+=("-Dgviz=ON")
CMAKE_PLATFORM_FLAGS+=("-Dhttp=ON")
CMAKE_PLATFORM_FLAGS+=("-Dimt=ON")
CMAKE_PLATFORM_FLAGS+=("-Dmathmore=ON")
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
if [[ "${target_platform}" == linux* ]]; then
    CMAKE_PLATFORM_FLAGS+=("-Dx11=ON")
else
    CMAKE_PLATFORM_FLAGS+=("-Dcocoa=ON")
fi
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

if [[ "${target_platform}" != osx* ]]; then
    # Can't use ninja on macOS due to "horrible hack to hide the LLVM/Clang symbols" (see below)
    CMAKE_PLATFORM_FLAGS+=("-GNinja")
fi

# Now we can actually run CMake
cmake $CMAKE_ARGS "${CMAKE_PLATFORM_FLAGS[@]}" ${SRC_DIR}/root-source

if [[ "${target_platform}" != "${build_platform}" ]]; then
    # Build rootcling_stage1 then substitute the binary with the host version
    cmake --build . --target rootcling_stage1 -- "-j${CPU_COUNT}"
    mv core/rootcling_stage1/src/rootcling_stage1{,.orig}
    cp "${SRC_DIR}/build-rootcling_stage1-xp/core/rootcling_stage1/src/rootcling_stage1" core/rootcling_stage1/src/rootcling_stage1
    touch -r core/rootcling_stage1/src/rootcling_stage1{.orig,}
fi

if [[ "${target_platform}" == osx* ]]; then
    # This is a horrible hack to hide the LLVM/Clang symbols in libCling.so on macOS
    cd core/metacling/src
    # First build libCling.so
    cmake --build . -- "-j${CPU_COUNT}"
    # Find the symbols in libCling.so
    nm -g ../../../lib/libCling.so | ruby -ne 'if /^[0-9a-f]+.*\s(\S+)$/.match($_) then print $1,"\n" end' | sort -u > original.exp
    # Find the symbols in the LLVM and Clang static libraries
    nm -g ${Clang_DIR}/lib/lib{LLVM,clang}*.a | ruby -ne 'if /^[0-9a-f]+.*\s(\S+)$/.match($_) then print $1,"\n" end' | sort -u > clang_and_llvm.exp
    # Find the difference, i.e. symbols that are in libCling.so but aren't defined in LLVM/Clang
    comm -23 original.exp clang_and_llvm.exp > allowed_symbols.exp
    # Add "-exported_symbols_list" to the link command
    sed -i "s@$CXX @$CXX -exported_symbols_list $PWD/allowed_symbols.exp @g" CMakeFiles/Cling.dir/link.txt
    # Build libCling.so again now the link command has been updated
    cmake --build . -- "-j${CPU_COUNT}"
    # Show some details about the number of symbols before and after in case further debugging is required
    nm -g ../../../lib/libCling.so | ruby -ne 'if /^[0-9a-f]+.*\s(\S+)$/.match($_) then print $1,"\n" end' | sort -u > new.exp
    wc -l *.exp
    cd -
fi

if [[ "${target_platform}" != "${build_platform}" ]]; then
    # Build rootcling then substitute the binary with the host version
    cmake --build . --target rootcling -- "-j${CPU_COUNT}"
    mv bin/rootcling{,.orig}
    cp "${SRC_DIR}/build-rootcling-xp/bin/rootcling" bin/rootcling
    touch -r bin/rootcling{.orig,}
fi

cmake --build . -- "-j${CPU_COUNT}"

if [[ "${target_platform}" != "${build_platform}" ]]; then
    # Restore the original rootcling_stage1/rootcling binaries
    mv core/rootcling_stage1/src/rootcling_stage1{.orig,}
    mv bin/rootcling{.orig,}
fi

# cd tutorials
# EXTRA_CLING_ARGS='-O1' LD_LIBRARY_PATH=$SRC_DIR/build-dir/lib: ROOTIGNOREPREFIX=1 ROOT_HIST=0 $SRC_DIR/build-dir/bin/root.exe -l -q -b -n -x hsimple.C -e return
# cd ..

if [ "${ROOT_CONDA_RUN_GTESTS-}" = "1" ]; then
    # Run gtests, never fail as Jenkins will check the test results instead
    ctest "-j${CPU_COUNT}" -T test --no-compress-output \
        --exclude-regex '^(pyunittests-pyroot-numbadeclare|test-periodic-build|tutorial-pyroot-pyroot004_NumbaDeclare-py)$' \
        || true
    rm -rf "${HOME}/feedstock_root/Testing"
    cp -rp "Testing" "${HOME}/feedstock_root/"
fi

cmake --build . --target install

# Remove thisroot.*
rm "${PREFIX}"/bin/thisroot.*
for suffix in sh csh fish; do
cp "${RECIPE_DIR}/thisroot" "${PREFIX}/bin/thisroot.${suffix}"
chmod +x "${PREFIX}/bin/thisroot.${suffix}"
done

# Install the jupyter kernel
mkdir -p "$PREFIX/share/jupyter/kernels"
cp -r "$PREFIX/etc/notebook/kernels/root" "$PREFIX/share/jupyter/kernels"

# Add the post activate/deactivate scripts
mkdir -p "${PREFIX}/etc/conda/activate.d"
cp "${RECIPE_DIR}/activate.sh" "${PREFIX}/etc/conda/activate.d/activate-root.sh"
cp "${RECIPE_DIR}/activate.csh" "${PREFIX}/etc/conda/activate.d/activate-root.csh"
cp "${RECIPE_DIR}/activate.fish" "${PREFIX}/etc/conda/activate.d/activate-root.fish"
mkdir -p "${PREFIX}/etc/conda/deactivate.d"
cp "${RECIPE_DIR}/deactivate.sh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.sh"
cp "${RECIPE_DIR}/deactivate.csh" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.csh"
cp "${RECIPE_DIR}/deactivate.fish" "${PREFIX}/etc/conda/deactivate.d/deactivate-root.fish"
