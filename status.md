Current status as of March 29, 2022.

## Problem

I cannot install [allensdk](https://github.com/AllenInstitute/AllenSDK)
(latest version 2.13.4) in a conda environment using the default conda-packaged python
with Python 3.8 or 3.9 running on Windows because:

1. allensdk has version bounds for `scikit-learn` that are too restrictive and incompatible with `numpy`:
  `scikit-image>=0.14.0,<0.17.0`. See https://github.com/AllenInstitute/AllenSDK/blob/master/requirements.txt .
  This is easily fixed and not an issue.

  * See also https://stackoverflow.com/questions/66174862/import-error-cant-import-name-gcd-from-fractions

1. allensdk has version bounds for `pytables` that do not work well for newer versions of python and windows:
  `tables>=3.6.0,<3.7.0`

  * pytables 3.6.x can be installed from wheels with python<3.9 on windows.

  * [Wheels for pytables 3.6.x](https://pypi.org/project/tables/3.6.1/#files) do not exist on PyPI for
    python==3.9 on windows (or macOS), so pytables must be built from source, which is difficult without
    the right environment and libraries. This error is raised:
    `LINK : fatal error LNK1181: cannot open input file 'hdf5.lib'`. I can work around this issue by:

    * Downloading and installing an unofficial, pre-built wheel for windows.

    * Temporarily setting the environment variable `LIB` before `pip install tables`:
       `set LIB=C:\Program Files\HDF_Group\HDF5\1.10.5\lib`

1. Updating allensdk to allow `tables==3.7.0` would be best but `tables==3.7.0` does not work well for certain
combinations of python, conda, and windows.

  * `pip install tables` in a conda environment using default conda-packaged python 3.8-3.9 on windows results
    in the error `ImportError: DLL load failed while importing utilsextension: The specified module could not be found.`
    See https://github.com/PyTables/PyTables/issues/933 for more details. This was due to a
    [change in Python 3.8](https://docs.python.org/3/whatsnew/3.8.html#bpo-36085-whatsnew) on how DLLs are loaded on
    Windows.

    * Supposedly, this is fixed in the Anaconda distribution of Python 3.9.9+ according to:
      https://github.com/adang1345/delvewheel/commit/ad638ac736d8c1e4115de44725a7e4492c06644d, though I cannot find any
      reference to this change.

    * Currently, calling `conda create --name test python=3.9` results in a conda environment with python 3.9.11.
      that does NOT say "packaged by conda-forge". The error still exists with this version of python.
      Note that 3.9.11 on defaults was released on Mar 28 2022, 04:40:48.

    * Currently, calling `conda create --name test python=3.10` results in a conda environment with python 3.10.3
      that says "packaged by conda-forge". The error does not exist with this version of python.

    * My tests with conda-forge versions of python 3.9 ("packaged by conda-forge")
      shows that `pip install tables` works OK on
      Python 3.9.9 but NOT Python 3.9.7 (3.9.8 was not available).
      `conda create --name test python=3.9.9 -c conda-forge --yes`.

    * My tests with conda-forge version of python 3.8 ("packaged by conda-forge")
      shows that `pip install tables` works OK on
      Python 3.8.13 (`conda-forge/win-64::python-3.8.13-hcf16a7b_0_cpython`) but NOT Python 3.8.12.

      `conda create --name test python=3.8 -c conda-forge --yes`.

      `conda create --name test conda-forge::python=3.8.12 -c conda-forge --yes` (need to specify source on python
      because python 3.8.12 is available on the default which currently takes priority).

      * Python 3.8.13 became available on conda-forge on Mar 25 2022, 05:59:00. See also
        https://github.com/conda-forge/python-feedstock/issues/444 . Bug fixes were backported from 3.10 to
        3.9.9 and 3.8.13 in conda-forge/python-feedstock.

    * So the claim about this issue being fixed in the Anaconda distribution of Python 3.9.9+
      might only be true of Python packaged from conda-forge - at least until the python distribution in
      the main conda channel is updated with this bugfix.  

  * One can work around this issue by:

    a. Installing only the latest python version distributed by conda-forge (3.8.13 for 3.8 series, 3.9.9 for 3.9
      series, and any 3.10.x).

    a. Installing the conda-forge version of pytables: `conda install pytables -c conda-forge`
      - The conda-forge version does not set `CONDA_DLL_SEARCH_MODIFICATION_ENABLE=1` or use `os.add_dll_directory`
        in `__init__.py`. It has no DLLs packaged with it, but it installs HDF5, BLOSC, etc. as separate packages.
        The `hdf5.dll` is installed at `C:\Users\Ryan\miniconda3\envs\test\Library\bin`. Is that why this works and
        the PyPI distribution does not?

    a. Setting the environment variable `CONDA_DLL_SEARCH_MODIFICATION_ENABLE=1` before importing `tables`.

## Trying different solutions

- The issue persists in newly generated wheels for pytables for Python 3.9 and Windows, based off of the latest
  main branch (as of 2022-03-28).
- In my pytables-test local repo, I can build the cython code using `python setup.py build_ext --inplace`
  and install the package "pip install -e ." and `import tables`. No error! What is missing?
- It is difficult to build wheels for this fork locally because I need to have a bunch of libraries installed. But I
  added a GitHub Action (modified from the existing one) that will do it. I could probably set it up locally.
- I have tried removing code from `utilsextension.pyx` but this will require a lot more work:
  https://github.com/rly/PyTables/actions
- Adding the `tables.libs` directory to `$PATH` at the beginning on `tables/__init__.py` works.
- These might be useful:
  - https://github.com/PyTables/PyTables/pull/787/files
  - https://github.com/conda-forge/pytables-feedstock/issues/31
  - https://github.com/theislab/scanpy/issues/2108
  - https://github.com/zeromq/pyzmq/pull/1498/files
- See also:
  - https://github.com/conda/conda/issues/10897
  - https://github.com/conda-forge/python-feedstock/issues/444
  - https://github.com/conda-forge/python-feedstock/issues/552
  - https://github.com/conda-forge/python-feedstock/issues/307


## Conclusion

While this issue could potentially be solved with code changes in pytables, because the windows DLL issue was
fixed in conda-forge distributions of Python 3.8.13+, 3.9.9+, and 3.10.x, this is no longer a blocking issue.
Changing the pytables code could help users using the default conda-packaged versions of python on conda on windows,
but they could use one of the workarounds described above. As such, I will no longer pursue a fix in pytables for this
but instead point to one of the above workarounds.
