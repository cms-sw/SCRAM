import sys
import re
from multiprocessing import cpu_count
from os import environ, unlink
from subprocess import getstatusoutput as run_cmd

regex_j = re.compile('^(-j|--jobs=)([0-9]*)$')
regex_number = re.compile('^[0-9]+$')
regex_0_or_none = re.compile('^(0+|)$')


# TODO proper way to pas command line arguments
class MakeInterface():

    def __init__(self):
        self.GMAKECMD = '${SCRAM_GMAKE_PATH}gmake'
        self.CMDOPTS = " -r"

    def exec(self, make_f_p):
        arg = ""
        job_args = 0
        job_val = ""

        for a in sys.argv[1:]:  # arguments passed to script
            # parse each command line argument
            m = regex_j.match(a)
            if m:
                # if '-j /--jobs' flag passed, store it
                job_args = 1
                job_val = m.group(2)
                continue
            if job_args and not job_val:
                # if flag was matched, but number was not passed
                if regex_number.match(a):  # check if next arguments are numbers and set them
                    job_val = a
                    continue
                else:
                    job_val = "0"  # else default to 0
            arg += " {0}".format(a)  # create arg string minus '-j /--jobs'
        if job_args:  # if '-j /--jobs' flag was passed
            if regex_0_or_none.match(job_val):  # but no core count, get max from the system
                job_val = cpu_count()
            arg += " '-j' '{0}'".format(job_val)

        # generate make command and execute it
        makecmd = self.GMAKECMD + self.CMDOPTS + " -f " + make_f_p + " " + arg
        errfile = environ["SCRAM_INTwork"] + "/build_error"
        try:
            unlink(errfile)
        except:
            pass  # nothing to unlink
        print(
            "({makecmd} && [ ! -e {errfile} ]) || (err=$?; echo gmake: \\*\\*\\* [There are compilation/build "
            "errors. Please see the detail log above.] Error $err && exit $err)"
            .format(makecmd=makecmd, errfile=errfile)
        )
        e, out = run_cmd(
            "({makecmd} && [ ! -e {errfile} ]) || (err=$?; echo gmake: \\*\\*\\* [There are compilation/build "
            "errors. Please see the detail log above.] Error $err && exit $err)"
            .format(makecmd=makecmd, errfile=errfile)
        )
        if e != 0:
            sys.exit("SCRAM MakeInterface::exec(): Unable to run gmake ...  {0}".format(out))
