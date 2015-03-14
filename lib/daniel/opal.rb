# This is a polyfill to provide crypto operations and some other operations that
# Opal is missing.  It provides the bare minimum required to get daniel to work,
# and nothing more.  Requires sjcl.

require 'daniel/opal/core'
require 'daniel/opal/crypto'
