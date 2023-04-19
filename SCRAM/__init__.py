# This will make sure that logging settings will be set in all module.
# Other settings could be set here (or in .ini file)
from sys import stdin, stdout, stderr, exit
import logging
from os import environ
import traceback

logging_config = {"format": '%(levelname)s %(funcName)10s %(lineno)3d: %(message)s'}
SCRAM_DEBUG = None
if "SCRAM_DEBUG" in environ:
    SCRAM_DEBUG = environ["SCRAM_DEBUG"]
    logging_config["level"] = logging.DEBUG
logging.basicConfig(**logging_config)

INTERACTIVE = False
if stdin.isatty() and stdout.isatty():
    INTERACTIVE = True
ORIGINAL_INTERACTIVE = INTERACTIVE

VERSION = 'V3_00_99'
FORCED_ARCH = ""
BASEPATH = '/cvmfs/cms.cern.ch'
BASEPATH_RW = '@CMS_PATH@'
COMMANDS_OPTS = None


def setDebug():
    global SCRAM_DEBUG
    SCRAM_DEBUG = True
    logging_config["level"] = logging.DEBUG
    logging.basicConfig(**logging_config)


def scramdebug(msg):
    if SCRAM_DEBUG:
        printmsg(msg)


def scramwinfo(msg):
    print("SCRAM %s" % info(msg), file=stdout)


def scramwarning(msg):
    print("SCRAM %s" % warning(msg), file=stderr)


def scramerror(msg):
    if SCRAM_DEBUG:
        traceback.print_stack(file=stderr)
    print("SCRAM %s" % error(msg), file=stderr)
    exit(1)


def scramfatal(msg):
    if SCRAM_DEBUG:
        traceback.print_stack(file=stderr)
    print("SCRAM %s" % fatal(msg), file=stderr)
    exit(1)


def printerror(msg):
    print(msg, file=stderr)


def printmsg(msg, if_interactive=True):
    if if_interactive:
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


def die(msg):
    if SCRAM_DEBUG:
        traceback.print_stack(file=stderr)
    print(msg + "\n", file=stderr)
    exit(1)


def run_command(command, debug=False, fail_on_error=False):
    try:
        from subprocess import getstatusoutput as run_cmd
    except Exception:
        from subprocess import call as run_cmd
    err, out = run_cmd(command)
    if err and fail_on_error:
        printerror(out)
        exit(1)
    if debug:
        printmsg(out)
    return err, out


# from SCRAM import metadata
# __version__ = metadata.version
# __author__ = metadata.authors[0]
# __license__ = metadata.license
# __copyright__ = metadata.copyright
