########################################################################
#
#       License: BSD
#       Created: March 03, 2008
#       Author:  Francesc Alted - faltet@pytables.com
#
#       $Id: definitions.pyd 1018 2005-06-20 09:43:34Z faltet $
#
########################################################################

"""
These are declarations for functions in utilsextension.pyx that have to
be shared with other extensions.
"""

from .definitions cimport hsize_t, hid_t, hobj_ref_t
from numpy cimport ndarray
