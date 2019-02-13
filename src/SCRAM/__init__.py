# This will make sure that logging settings will be set in all module.
# Other settings could be set here (or in .ini file)
import logging
FORMAT = '%(levelname)s - %(funcName)s - %(lineno)d: %(message)s'
logging.basicConfig(format=FORMAT)

# TODO to change logging config on runtime ( like by passing params from
# command line, do `logging.getLogger().setLevel(logging.DEBUG)`

from sys import stdin, stdout
INTERACTIVE = False
if stdin.isatty() and stdout.isatty(): INTERACTIVE=True

VERSION='V3_0_0'
FORCED_ARCH=""
BASEPATH='/cvmfs/cms.cern.ch'
