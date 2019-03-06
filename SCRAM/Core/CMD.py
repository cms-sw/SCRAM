import SCRAM
from SCRAM.Core.Core import Core


def cmd_version(args):
    print("%s" % SCRAM.VERSION)
    return True


def cmd_help(args):
    SCRAM.run_command('man scram')
    return True


def cmd_arch(args):
    c = Core()
    SCRAM.printmsg("%s" % environ['SCRAM_ARCH'])
    return True


def cmd_list(args):
    from SCRAM.Core.Commands.runtime import runtime
    process(args)


def cmd_build(args):
    spawnversion()
    return True


def cmd_config(args):
    from SCRAM.Core.Commands.config import process
    process(args)


def cmd_db(args):
    from SCRAM.Core.Commands.db import process
    process(args)


def cmd_setup(args):
    from SCRAM.Core.Commands.setup import process
    process(args)


def cmd_unsetenv(args):
    from SCRAM.Core.Commands.runtime import process_unsetenv
    unsetenv(args)


def cmd_runtime(args):
    from SCRAM.Core.Commands.runtime import process_runtime
    runtime(args)


def cmd_project(args):
    from SCRAM.Core.Commands.project import process
    process(args)


def cmd_tool(args):
    from SCRAM.Core.Commands.tool import process
    process(args, Core())
