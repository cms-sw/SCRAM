def cmd_version(args):
    from SCRAM import printmsg
    printmsg("%s" % SCRAM.VERSION)
    return True


def cmd_help(args):
    from SCRAM import run_command
    run_command('man scram')
    return True


def cmd_arch(args):
    from SCRAM import printmsg
    from os import environ
    from SCRAM.Core.Core import Core
    c = Core()
    printmsg("%s" % environ['SCRAM_ARCH'])
    return True


def cmd_list(args):
    from SCRAM.Core.Commands.list import process
    return process(args)


def cmd_build(args):
    from SCRAM.Core.Commands.build import process
    return process(args)


def cmd_config(args):
    from SCRAM.Core.Commands.config import process
    return process(args)


def cmd_db(args):
    from SCRAM.Core.Commands.db import process
    return process(args)


def cmd_setup(args):
    from SCRAM.Core.Commands.setup import process
    return process(args)


def cmd_unsetenv(args):
    from SCRAM.Core.Commands.runtime import process_unsetenv as process
    return process(args)


def cmd_runtime(args):
    from SCRAM.Core.Commands.runtime import process_runtime as process
    return process(args)


def cmd_project(args):
    from SCRAM.Core.Commands.project import process
    return process(args)


def cmd_tool(args):
    from SCRAM.Core.Commands.tool import process
    return process(args)
