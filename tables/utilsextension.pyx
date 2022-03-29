########################################################################
#
# License: BSD
# Created: May 20, 2005
# Author:  Francesc Alted - faltet@pytables.com
#
# $Id$
#
########################################################################

"""Cython utilities for PyTables and HDF5 library."""

import os
import sys
import warnings

try:
  import zlib
  zlib_imported = True
except ImportError:
  zlib_imported = False

import numpy

from .description import Description, Col
from .misc.enum import Enum
from .exceptions import HDF5ExtError
from .atom import Atom, EnumAtom, ReferenceAtom

from .utils import check_file_access

from libc.stdio cimport stderr
from libc.stdlib cimport malloc, free
from libc.string cimport strchr, strcmp, strncmp, strlen
from cpython.bytes cimport PyBytes_Check, PyBytes_FromStringAndSize
from cpython.unicode cimport PyUnicode_DecodeUTF8, PyUnicode_Check

from numpy cimport (import_array, ndarray, dtype,
  npy_int64, PyArray_DATA, PyArray_GETPTR1, PyArray_DescrFromType, npy_intp,
  NPY_BOOL, NPY_STRING, NPY_INT8, NPY_INT16, NPY_INT32, NPY_INT64,
  NPY_UINT8, NPY_UINT16, NPY_UINT32, NPY_UINT64, NPY_FLOAT16, NPY_FLOAT32,
  NPY_FLOAT64, NPY_COMPLEX64, NPY_COMPLEX128)

from .definitions cimport (H5ARRAYget_info, H5ARRAYget_ndims,
  H5ATTRfind_attribute, H5ATTRget_attribute_string, H5D_CHUNKED,
  H5D_layout_t, H5Dclose, H5Dget_type, H5Dopen, H5E_DEFAULT,
  H5E_WALK_DOWNWARD, H5E_auto_t, H5E_error_t, H5E_walk_t, H5Eget_msg,
  H5Eprint, H5Eset_auto, H5Ewalk, H5F_ACC_RDONLY, H5Fclose, H5Fis_hdf5,
  H5Fopen, H5Gclose, H5Gopen, H5P_DEFAULT, H5T_ARRAY, H5T_BITFIELD,
  H5T_COMPOUND, H5T_CSET_ASCII, H5T_CSET_UTF8, H5T_C_S1, H5T_DIR_DEFAULT,
  H5T_ENUM, H5T_FLOAT, H5T_IEEE_F32BE, H5T_IEEE_F32LE, H5T_IEEE_F64BE,
  H5T_IEEE_F64LE, H5T_INTEGER, H5T_NATIVE_DOUBLE, H5T_NATIVE_LDOUBLE,
  H5T_NO_CLASS, H5T_OPAQUE,
  H5T_ORDER_BE, H5T_ORDER_LE, H5T_REFERENCE, H5T_STD_B8BE, H5T_STD_B8LE,
  H5T_STD_I16BE, H5T_STD_I16LE, H5T_STD_I32BE, H5T_STD_I32LE, H5T_STD_I64BE,
  H5T_STD_I64LE, H5T_STD_I8BE, H5T_STD_I8LE, H5T_STD_U16BE, H5T_STD_U16LE,
  H5T_STD_U32BE, H5T_STD_U32LE, H5T_STD_U64BE, H5T_STD_U64LE, H5T_STD_U8BE,
  H5T_STD_U8LE, H5T_STRING, H5T_TIME, H5T_UNIX_D32BE, H5T_UNIX_D32LE,
  H5T_UNIX_D64BE, H5T_UNIX_D64LE, H5T_VLEN, H5T_class_t, H5T_sign_t,
  H5Tarray_create, H5Tclose, H5Tequal, H5Tcopy, H5Tcreate, H5Tenum_create,
  H5Tenum_insert, H5Tget_array_dims, H5Tget_array_ndims, H5Tget_class,
  H5Tget_member_name, H5Tget_member_type, H5Tget_member_value,
  H5Tget_native_type, H5Tget_nmembers, H5Tget_offset, H5Tget_order,
  H5Tget_member_offset,
  H5Tget_precision, H5Tget_sign, H5Tget_size, H5Tget_super, H5Tinsert,
  H5Tis_variable_str, H5Tpack, H5Tset_precision, H5Tset_size, H5Tvlen_create,
  H5Zunregister, FILTER_BLOSC,
  PyArray_Scalar, create_ieee_complex128, create_ieee_complex64,
  create_ieee_float16, create_ieee_complex192, create_ieee_complex256,
  get_len_of_range, get_order, herr_t, hid_t, hsize_t,
  hssize_t, htri_t, is_complex, register_blosc, set_order,
  pt_H5free_memory, H5T_STD_REF_OBJ, H5Rdereference, H5R_OBJECT, H5I_DATASET, H5I_REFERENCE,
  H5Iget_type, hobj_ref_t, H5Oclose)



# Platform-dependent types
if sys.byteorder == "little":
  platform_byteorder = H5T_ORDER_LE
  # Standard types, independent of the byteorder
  H5T_STD_B8   = H5T_STD_B8LE
  H5T_STD_I8   = H5T_STD_I8LE
  H5T_STD_I16  = H5T_STD_I16LE
  H5T_STD_I32  = H5T_STD_I32LE
  H5T_STD_I64  = H5T_STD_I64LE
  H5T_STD_U8   = H5T_STD_U8LE
  H5T_STD_U16  = H5T_STD_U16LE
  H5T_STD_U32  = H5T_STD_U32LE
  H5T_STD_U64  = H5T_STD_U64LE
  H5T_IEEE_F32 = H5T_IEEE_F32LE
  H5T_IEEE_F64 = H5T_IEEE_F64LE
  H5T_UNIX_D32  = H5T_UNIX_D32LE
  H5T_UNIX_D64  = H5T_UNIX_D64LE
else:  # sys.byteorder == "big"
  platform_byteorder = H5T_ORDER_BE
  # Standard types, independent of the byteorder
  H5T_STD_B8   = H5T_STD_B8BE
  H5T_STD_I8   = H5T_STD_I8BE
  H5T_STD_I16  = H5T_STD_I16BE
  H5T_STD_I32  = H5T_STD_I32BE
  H5T_STD_I64  = H5T_STD_I64BE
  H5T_STD_U8   = H5T_STD_U8BE
  H5T_STD_U16  = H5T_STD_U16BE
  H5T_STD_U32  = H5T_STD_U32BE
  H5T_STD_U64  = H5T_STD_U64BE
  H5T_IEEE_F32 = H5T_IEEE_F32BE
  H5T_IEEE_F64 = H5T_IEEE_F64BE
  H5T_UNIX_D32  = H5T_UNIX_D32BE
  H5T_UNIX_D64  = H5T_UNIX_D64BE


#----------------------------------------------------------------------------

# Conversion from PyTables string types to HDF5 native types
# List only types that are susceptible of changing byteorder
# (complex & enumerated types are special and should not be listed here)
pttype_to_hdf5 = {
  'int8'   : H5T_STD_I8,   'uint8'  : H5T_STD_U8,
  'int16'  : H5T_STD_I16,  'uint16' : H5T_STD_U16,
  'int32'  : H5T_STD_I32,  'uint32' : H5T_STD_U32,
  'int64'  : H5T_STD_I64,  'uint64' : H5T_STD_U64,
  'float32': H5T_IEEE_F32, 'float64': H5T_IEEE_F64,
  'float96': H5T_NATIVE_LDOUBLE, 'float128': H5T_NATIVE_LDOUBLE,
  'time32' : H5T_UNIX_D32, 'time64' : H5T_UNIX_D64,
}

# Special cases whose byteorder cannot be directly changed
pt_special_kinds = ['complex', 'string', 'enum', 'bool']

# Conversion table from NumPy extended codes prefixes to PyTables kinds
npext_prefixes_to_ptkinds = {
  "S": "string",
  "b": "bool",
  "i": "int",
  "u": "uint",
  "f": "float",
  "c": "complex",
  "t": "time",
  "e": "enum",
}

# Names of HDF5 classes
hdf5_class_to_string = {
  H5T_NO_CLASS  : 'H5T_NO_CLASS',
  H5T_INTEGER   : 'H5T_INTEGER',
  H5T_FLOAT     : 'H5T_FLOAT',
  H5T_TIME      : 'H5T_TIME',
  H5T_STRING    : 'H5T_STRING',
  H5T_BITFIELD  : 'H5T_BITFIELD',
  H5T_OPAQUE    : 'H5T_OPAQUE',
  H5T_COMPOUND  : 'H5T_COMPOUND',
  H5T_REFERENCE : 'H5T_REFERENCE',
  H5T_ENUM      : 'H5T_ENUM',
  H5T_VLEN      : 'H5T_VLEN',
  H5T_ARRAY     : 'H5T_ARRAY',
}


# Depprecated API
PTTypeToHDF5 = pttype_to_hdf5
PTSpecialKinds = pt_special_kinds
NPExtPrefixesToPTKinds = npext_prefixes_to_ptkinds
HDF5ClassToString = hdf5_class_to_string


from numpy import sctypeDict
cdef int have_float16 = ("float16" in sctypeDict)


#----------------------------------------------------------------------

# External declarations
print('hello')

# PyTables helper routines.
cdef extern from "utils.h":

  int getLibrary(char *libname) nogil
  #object getZLIBVersionInfo()
  object getHDF5VersionInfo()
  object get_filter_names( hid_t loc_id, char *dset_name)

  H5T_class_t getHDF5ClassID(hid_t loc_id, char *name, H5D_layout_t *layout,
                             hid_t *type_id, hid_t *dataset_id) nogil

print('goodbye')

# Functions from Blosc
cdef extern from "blosc.h" nogil:
  void blosc_init()
  int blosc_set_nthreads(int nthreads)
  const char* blosc_list_compressors()
  int blosc_compcode_to_compname(int compcode, char **compname)
  int blosc_get_complib_info(char *compname, char **complib, char **version)

cdef extern from "H5ARRAY.h" nogil:
  herr_t H5ARRAYread(hid_t dataset_id, hid_t type_id,
                     hsize_t start, hsize_t nrows, hsize_t step,
                     int extdim, void *data)

# @TODO: use the c_string_type and c_string_encoding global directives
#        (new in cython 0.19)
# TODO: drop
cdef str cstr_to_pystr(const char* cstring):
  return cstring.decode('utf-8')


def get_hdf5_version():
  return "1.10.6"
