import os
from subprocess import getstatusoutput as cmd
from __main__ import args


def clean_env():
    for var in [e for e in os.environ.keys() if e.startswith("_SCRAM_SYSVAR_")]:
        val = os.environ[var]
        del os.environ[var]
        var = var[14:]
        if val:
            os.environ[var] = val
        else:
            del os.environ[var]


def run_cmd():
    print(args)
    print(cmd(' '.join(args)))
