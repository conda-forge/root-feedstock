#!/usr/bin/env python
import sys
import ROOT

@ROOT.Numba.Declare(["float"], "float")
def fn(x):
    return x**2


assert fn(6) == 36

# ROOT doesn't like how conda-forge's Python 3.6 binaries are linked
# This is expected to fail but it should be fixed upstream rather than patched here
if sys.version_info >= (3, 7):
    assert ROOT.TPython.Exec("print(1+1)")
    assert int(ROOT.TPython.Eval("1+1")) == 2
