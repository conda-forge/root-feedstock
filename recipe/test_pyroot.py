#!/usr/bin/env python
import ROOT


@ROOT.Numba.Declare(["float"], "float")
def fn(x):
    return x**2


assert fn(6) == 36
