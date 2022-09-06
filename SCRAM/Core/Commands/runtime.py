from os import environ
import SCRAM
from SCRAM.Core.RuntimeEnv import RUNTIME_SHELLS, RuntimeEnv

def clean_build_env():
  for e in ["SCRAM_RTBOURNE_SET"]:
    if e in environ:
      del environ[e]
  return

def process_unsetenv(args):
    if (len(args) != 1) or (args[0] not in RUNTIME_SHELLS):
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    clean_build_env()
    rt = RuntimeEnv(area=None)
    rt.unsetenv(RUNTIME_SHELLS[args[0]])
    return True


def process_runtime(args):
    if (len(args) == 0) or (args[0] not in RUNTIME_SHELLS):
        SCRAM.scramfatal("Error parsing arguments. See \"scram -help\" for usage info.")
    from SCRAM.Core.Core import Core
    clean_build_env()
    area = Core()
    area.checklocal()
    area.init_env()
    rt = RuntimeEnv(area.localarea())
    rt.optional_env(args[1:])
    rt.save(RUNTIME_SHELLS[args[0]])
    rt.setenv(RUNTIME_SHELLS[args[0]])
    return True
