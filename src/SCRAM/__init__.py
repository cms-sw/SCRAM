# This will make sure that logging settings will be set in all module.
# Other settings could be set here (or in .ini file)
from sys import stdin, stdout, stderr, exit
import logging
FORMAT = '%(levelname)s - %(funcName)s - %(lineno)d: %(message)s'
logging.basicConfig(format=FORMAT)

# TODO to change logging config on runtime ( like by passing params from
# command line, do `logging.getLogger().setLevel(logging.DEBUG)`

INTERACTIVE = False
if stdin.isatty() and stdout.isatty():
    INTERACTIVE = True

VERSION = 'V3_0_0'
FORCED_ARCH = ""
BASEPATH = '/cvmfs/cms.cern.ch'


def scramwinfo(msg):
    print("SCRAM %s" % info(msg), file=stdout)


def scramwarning(msg):
    print("SCRAM %s" % warning(msg), file=stderr)


def scramerror(msg):
    print("SCRAM %s" % error(msg), file=stderr)
    exit(1)


def scramfatel(msg):
    print("SCRAM %s" % fatel(msg), file=stderr)
    exit(1)


def printrror(msg):
    print(msg, file=stderr)


def printmsg(msg):
    print(msg)


def msg(data):
    return "> %s" % data


def warning(data):
    return "warning: %s" % data


def error(data):
    return "error: %s" % data


def fatel(data):
    return "fatel: %s" % data


def info(data):
    return "info: %s" % data
