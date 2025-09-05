# Taken from https://github.com/conda-forge/ctng-compiler-activation-feedstock/blob/e2bdf15eb170008eda386056a900ce93e0f9cb16/recipe/get_cpu_arch.sh

get_triplet() {
  local CPU_ARCH
  if [[ "$1" == *"-64" ]]; then
    CPU_ARCH="x86_64"
  elif [[ "$1" == *"-ppc64le" ]]; then
    CPU_ARCH="powerpc64le"
  elif [[ "$1" == *"-aarch64" ]]; then
    CPU_ARCH="aarch64"
  elif [[ "$1" == *"-s390x" ]]; then
    CPU_ARCH="s390x"
  elif [[ "$1" == *"-arm64" ]]; then
    CPU_ARCH="arm64"
  else
    echo "Unknown architecture"
    exit 1
  fi
  if [[ "$1" == "linux-"* ]]; then
    echo $CPU_ARCH-conda-linux-gnu
  elif [[ "$1" == "osx-64" ]]; then
    echo x86_64-apple-darwin13.4.0
  elif [[ "$1" == "osx-arm64" ]]; then
    echo arm64-apple-darwin20.0.0
  elif [[ "$1" == "win-64" ]]; then
    echo x86_64-w64-mingw32
  fi
}

export CHOST="$(get_triplet ${target_platform})"
