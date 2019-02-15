# This will make sure that logging settings will be set in all module.
# Other settings could be set here (or in .ini file)
from sys import stdin, stdout, stderr, exit
import logging
FORMAT = '%(levelname)s - %(funcName)s - %(lineno)d: %(message)s'
logging.basicConfig(format=FORMAT, level=logging.INFO)

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


def scramfatal(msg):
    print("SCRAM %s" % fatal(msg), file=stderr)
    exit(1)


def printerror(msg):
    print(msg, file=stderr)


def printmsg(msg):
    print(msg, file=stdout)


def msg(data):
    return "> %s" % data


def warning(data):
    return "warning: %s" % data


def error(data):
    return "error: %s" % data


def fatal(data):
    return "fatal: %s" % data


def info(data):
    return "info: %s" % data


def run_command(command, debug=False, fail_on_error=False):
    try:
        from subprocess import run as run_command
    except:
        from subprocess import call as run_command
    err, out = run_cmd(command)
    if err and fail_on_error:
        printerror(out)
        exit(1)
    if debug:
        printmsg(out)
    return err, out
