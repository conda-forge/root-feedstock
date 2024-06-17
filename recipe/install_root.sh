#!/bin/bash
set -ex

cd build-dir
make install

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
