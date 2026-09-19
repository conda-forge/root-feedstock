# ROOT packaging on conda-forge

This page is meant for maintainers of other packages on conda-forge that depend on ROOT.

The recipe currently produces three packages

- `root_cxx_standard`: A marker package that exposes the ROOT C++ standard used in a certain build variant.
- `root_base`: The full set of ROOT libraries and functionality in Python and C++.
- `root`: The same artifacts as `root_base`, but adds runtime requirements on useful Python packages for certain features of ROOT.

## When should I use each package?

The `root` package caters the final user who wants to get all ROOT functionalities with the convenience of having also
relevant Python dependencies automatically installed in the same environment. For example, `root` pulls in the Jupyter
notebook and numba dependencies which may be used together with ROOT in certain scenarios.

Maintainers of other packages on conda-forge may want to depend on `root_base` alone. This package will ship all the
ROOT libraries so that other projects may link against them. It also ships the C++ interpreter, as well as the ROOT
Python bindings.

The `root_cxx_standard` marker is necessary to avoid subtle ABI incompatibilities. It signals which version of the C++
standard was used to build `root_base` with. Downstream packages should compile with the same C++ standard version and
thus also add this package to their recipe requirements section as needed. The following will generate one build per C++
standard version used to build the corresponding ROOT package:

```
requirements:
  build:
    - root_base X.YY.*
    - root_cxx_standard
```
