def cmd_version(args, opts):
    from SCRAM import printmsg, VERSION
    printmsg("%s" % VERSION)
    return True


def cmd_help(args, opts):
    from os import system
    system("man scram")


def cmd_arch(args, opts):
    from SCRAM import printmsg
    from os import environ
    from SCRAM.Core.Core import Core
    Core()
    printmsg("%s" % environ['SCRAM_ARCH'])
    return True


def cmd_list(args, opts):
    from SCRAM.Core.Commands.list import process
    return process(args)


def cmd_build(args, opts):
    from SCRAM.Core.Commands.build import process
    return process(args, opts)


def cmd_config(args, opts):
    from SCRAM.Core.Commands.config import process
    return process(args)


def cmd_db(args, opts):
    from SCRAM.Core.Commands.db import process
    return process(args)


def cmd_setup(args, opts):
    from SCRAM.Core.Commands.setup import process
    return process(args)


def cmd_unsetenv(args, opts):
    from SCRAM.Core.Commands.runtime import process_unsetenv as process
    return process(args)


def cmd_runtime(args, opts):
    from SCRAM.Core.Commands.runtime import process_runtime as process
    return process(args)


def cmd_project(args, opts):
    from SCRAM.Core.Commands.project import process
    return process(args)


def cmd_tool(args, opts):
    from SCRAM.Core.Commands.tool import process
    return process(args)
