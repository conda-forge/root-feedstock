#!/usr/bin/env python
import ROOT


@ROOT.Numba.Declare(["float"], "float")
def fn(x):
    return x**2


assert fn(6) == 36

assert ROOT.TPython.Exec("print(1+1)")
assert int(ROOT.TPython.Eval("1+1")) == 2
