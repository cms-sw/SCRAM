import sys, os
try:
  from subprocess import run as run_cmd
except:
  from subprocess import call as run_cmd
import SCRAM


def cmd_version(args):
    print("%s" % SCRAM.VERSION)
    return True


def cmd_help(args):
    run_cmd(['man','scram'])
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
    from SCRAM.Core.ProjectDB import ProjectDB
    d =ProjectDB()
    d.getarea('CMSSW', 'CMSSW_10_5_0_pre1')
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
