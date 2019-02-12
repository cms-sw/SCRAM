import sys, os
from subprocess import run
from __main__ import SCRAM_VERSION, SCRAM_BASEPATH


def cmd_version(args):
    print("%s" % SCRAM_VERSION)
    return True


def cmd_help(args):
    run(['man', 'scram'])
    return True;


def cmd_arch(args):
    print("%s" % os.environ['SCRAM_ARCH'])
    return True


def spawnversion(newversion='V2_99_99'):
    os.environ['SCRAM_VERSION'] = newversion
    os.execv(SCRAM_BASEPATH + "/common/scram", sys.argv)


def cmd_unsetenv(args):
    spawnversion()
    return True


def cmd_list(args):
    spawnversion()
    return True


def cmd_build(args):
    spawnversion()
    return True


def cmd_config(args):
    spawnversion()
    return True


def cmd_db(args):
    spawnversion()
    return True


def cmd_project(args):
    spawnversion()
    return True


def cmd_runtime(args):
    spawnversion()
    return True


def cmd_setup(args):
    spawnversion()
    return True


def cmd_tool(args):
    spawnversion()
    return True
