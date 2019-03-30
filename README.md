About root
==========

Home: https://root.cern/

Package license: LGPL-2.1

Feedstock license: BSD 3-Clause

Summary: ROOT is a modular scientific software toolkit. It provides all the functionalities needed to deal with big data
processing, statistical analysis, visualisation and storage. It is mainly written in C++ but integrated with other
languages such as Python and R.


Almost everything in ROOT should be supported in this Conda package; ROOT was built with lots of options turned
on. Here are a few things to try:

* `root`: you can start up a session and see the splash screen; Control-D to exit.
* `python` followed by `import ROOT` will load PyROOT.
* `root --notebook` will start a notebook server with a ROOT kernel choice.
* `rootbrowse` will open a TBrowser session so you can look through files.
* `root -l -q $ROOTSYS/tutorials/dataframe/df013_InspectAnalysis.C` will run a DataFrame example with an animated plot.
* `root -b -q -l -n -e "std::cout << TROOT::GetTutorialDir() << std::endl;"` will print the tutorial dir.
* `root -b -l -q -e 'std::cout << (float) TPython::Eval("1+1") << endl;'` will run Python from C++ ROOT.

See the post [here](https://iscinumpy.gitlab.io/post/root-conda/) for more information about using this Conda package.

Caveats
=======

General
-------

The ROOT package will prepare the required compilers (see below). Everything in Conda is symlinked into
`$CONDA_PREFIX` if you build things by hand; tools like CMake should find it automatically. The `thisroot.*`
scripts should not be used. Graphics, `rootbrowse`, etc. all should work.

Linux
-----

On Linux, there really aren't any special caveats, just a few general to Conda itself, and the compilers package.
When ROOT is in the active environment, `g++` and `$CXX` are the conda compilers, GCC 7.3.

ROOT was built with and will report `-std=c++17` from `root-config`.


macOS
-----

The caveats on macOS are a bit larger, but have the same reason for existing as on Linux. When ROOT is in the
active environment, `clang++` and `$CXX` will be the Conda compilers; but those compilers are Clang 4.0 and the
macOS 10.9 SDK.  You must install the macOS 10.9 SDK, [as mentioned in the conda
documentation](https://conda.io/projects/conda-build/en/latest/source/compiler-tools.html#macos-sdk), if you want
to build anything.  And, while normal ROOT and PyROOT are fine, commands like `root MyFile.C+` actively build
things, so this is probably something many users will want to do. Once the macOS is downloaded and extracted on
your system, you should set `CONDA_BUILD_SYSROOT` to point to the SDK root location, such as
`/opt/MacOSX10.9.sdk`. This will not be necessary once ROOT moves to using LLVM 8.

ROOT does not link to Python directly in order to properly support PyROOT from Python, but has been patched to
provide the correct behavior to allow PyROOT to also be used from ROOT's C++ command line.

ROOT was built with and will report `-std=c++1z` from `root-config`.


Current build status
====================


<table>
    
  <tr>
    <td>Azure</td>
    <td>
      <details>
        <summary>
          <a href="https://dev.azure.com/conda-forge/feedstock-builds/_build/latest?definitionId=2612&branchName=master">
            <img src="https://dev.azure.com/conda-forge/feedstock-builds/_apis/build/status/root-feedstock?branchName=master">
          </a>
        </summary>
        <table>
          <thead><tr><th>Variant</th><th>Status</th></tr></thead>
          <tbody><tr>
              <td>linux_python2.7</td>
              <td>
                <a href="https://dev.azure.com/conda-forge/feedstock-builds/_build/latest?definitionId=2612&branchName=master">
                  <img src="https://dev.azure.com/conda-forge/feedstock-builds/_apis/build/status/root-feedstock?branchName=master&jobName=linux&configuration=linux_python2.7" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>linux_python3.6</td>
              <td>
                <a href="https://dev.azure.com/conda-forge/feedstock-builds/_build/latest?definitionId=2612&branchName=master">
                  <img src="https://dev.azure.com/conda-forge/feedstock-builds/_apis/build/status/root-feedstock?branchName=master&jobName=linux&configuration=linux_python3.6" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>linux_python3.7</td>
              <td>
                <a href="https://dev.azure.com/conda-forge/feedstock-builds/_build/latest?definitionId=2612&branchName=master">
                  <img src="https://dev.azure.com/conda-forge/feedstock-builds/_apis/build/status/root-feedstock?branchName=master&jobName=linux&configuration=linux_python3.7" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_python2.7</td>
              <td>
                <a href="https://dev.azure.com/conda-forge/feedstock-builds/_build/latest?definitionId=2612&branchName=master">
                  <img src="https://dev.azure.com/conda-forge/feedstock-builds/_apis/build/status/root-feedstock?branchName=master&jobName=osx&configuration=osx_python2.7" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_python3.6</td>
              <td>
                <a href="https://dev.azure.com/conda-forge/feedstock-builds/_build/latest?definitionId=2612&branchName=master">
                  <img src="https://dev.azure.com/conda-forge/feedstock-builds/_apis/build/status/root-feedstock?branchName=master&jobName=osx&configuration=osx_python3.6" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_python3.7</td>
              <td>
                <a href="https://dev.azure.com/conda-forge/feedstock-builds/_build/latest?definitionId=2612&branchName=master">
                  <img src="https://dev.azure.com/conda-forge/feedstock-builds/_apis/build/status/root-feedstock?branchName=master&jobName=osx&configuration=osx_python3.7" alt="variant">
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </details>
    </td>
  </tr>
  <tr>
    <td>Windows</td>
    <td>
      <img src="https://img.shields.io/badge/Windows-disabled-lightgrey.svg" alt="Windows disabled">
    </td>
  </tr>
</table>

Current release info
====================

| Name | Downloads | Version | Platforms |
| --- | --- | --- | --- |
| [![Conda Recipe](https://img.shields.io/badge/recipe-root-green.svg)](https://anaconda.org/conda-forge/root) | [![Conda Downloads](https://img.shields.io/conda/dn/conda-forge/root.svg)](https://anaconda.org/conda-forge/root) | [![Conda Version](https://img.shields.io/conda/vn/conda-forge/root.svg)](https://anaconda.org/conda-forge/root) | [![Conda Platforms](https://img.shields.io/conda/pn/conda-forge/root.svg)](https://anaconda.org/conda-forge/root) |

Installing root
===============

Installing `root` from the `conda-forge` channel can be achieved by adding `conda-forge` to your channels with:

```
conda config --add channels conda-forge
```

Once the `conda-forge` channel has been enabled, `root` can be installed with:

```
conda install root
```

It is possible to list all of the versions of `root` available on your platform with:

```
conda search root --channel conda-forge
```


About conda-forge
=================

[![Powered by NumFOCUS](https://img.shields.io/badge/powered%20by-NumFOCUS-orange.svg?style=flat&colorA=E1523D&colorB=007D8A)](http://numfocus.org)

conda-forge is a community-led conda channel of installable packages.
In order to provide high-quality builds, the process has been automated into the
conda-forge GitHub organization. The conda-forge organization contains one repository
for each of the installable packages. Such a repository is known as a *feedstock*.

A feedstock is made up of a conda recipe (the instructions on what and how to build
the package) and the necessary configurations for automatic building using freely
available continuous integration services. Thanks to the awesome service provided by
[CircleCI](https://circleci.com/), [AppVeyor](https://www.appveyor.com/)
and [TravisCI](https://travis-ci.org/) it is possible to build and upload installable
packages to the [conda-forge](https://anaconda.org/conda-forge)
[Anaconda-Cloud](https://anaconda.org/) channel for Linux, Windows and OSX respectively.

To manage the continuous integration and simplify feedstock maintenance
[conda-smithy](https://github.com/conda-forge/conda-smithy) has been developed.
Using the ``conda-forge.yml`` within this repository, it is possible to re-render all of
this feedstock's supporting files (e.g. the CI configuration files) with ``conda smithy rerender``.

For more information please check the [conda-forge documentation](https://conda-forge.org/docs/).

Terminology
===========

**feedstock** - the conda recipe (raw material), supporting scripts and CI configuration.

**conda-smithy** - the tool which helps orchestrate the feedstock.
                   Its primary use is in the construction of the CI ``.yml`` files
                   and simplify the management of *many* feedstocks.

**conda-forge** - the place where the feedstock and smithy live and work to
                  produce the finished article (built conda distributions)


Updating root-feedstock
=======================

If you would like to improve the root recipe or build a new
package version, please fork this repository and submit a PR. Upon submission,
your changes will be run on the appropriate platforms to give the reviewer an
opportunity to confirm that the changes result in a successful build. Once
merged, the recipe will be re-built and uploaded automatically to the
`conda-forge` channel, whereupon the built conda packages will be available for
everybody to install and use from the `conda-forge` channel.
Note that all branches in the conda-forge/root-feedstock are
immediately built and any created packages are uploaded, so PRs should be based
on branches in forks and branches in the main repository should only be used to
build distinct package versions.

In order to produce a uniquely identifiable distribution:
 * If the version of a package **is not** being increased, please add or increase
   the [``build/number``](https://conda.io/docs/user-guide/tasks/build-packages/define-metadata.html#build-number-and-string).
 * If the version of a package **is** being increased, please remember to return
   the [``build/number``](https://conda.io/docs/user-guide/tasks/build-packages/define-metadata.html#build-number-and-string)
   back to 0.

Feedstock Maintainers
=====================

* [@bluehood](https://github.com/bluehood/)
* [@chrisburr](https://github.com/chrisburr/)
* [@egpbos](https://github.com/egpbos/)
* [@henryiii](https://github.com/henryiii/)

