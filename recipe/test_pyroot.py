#!/usr/bin/env python
import sys
import ROOT

def test_1():
    if sys.version_info >= (3, 8): # Minimum supported Python version by ROOT
        try:
            import numba
        except ImportError:
            print("Skipping numba test")
            return

        @ROOT.Numba.Declare(["float"], "float")
        def fn(x):
            return x**2

        assert fn(6) == 36

def test_2():
    assert ROOT.TPython.Exec("print('1 + 1 =', 1+1)")

if __name__ == "__main__":
    test_1()
    test_2()
