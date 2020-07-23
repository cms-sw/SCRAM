import re
from SCRAM import scramerror
from multiprocessing import cpu_count
from os import environ, execl

regex_j = re.compile('^(-j|--jobs=)([0-9]*)$')
regex_number = re.compile('^[0-9]+$')
regex_0_or_none = re.compile('^(0+|)$')


# TODO proper way to pas command line arguments
class MakeInterface:

    def exec(self, make_f_p, args, opts):
        arg = ["-r", "-f", make_f_p]
        job_args = 0
        job_val = ""

        for a in args:  # arguments passed to script
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
            arg.append(a)  # create arg string minus '-j /--jobs'
        if job_args:  # if '-j /--jobs' flag was passed
            if regex_0_or_none.match(job_val):  # but no core count, get max from the system
                job_val = cpu_count()
            arg.append("-j")
            arg.append(job_val)

        # generate make command and execute it
        if opts.verbose:
            environ["SCRAM_BUILDVERBOSE"] = "1"
        script = "%s/%s/SCRAM/scram_build.sh" % (environ['LOCALTOP'], environ['SCRAM_CONFIGDIR'])
        try:
            execl(script, *arg)
        except Exception as e:
            scramerror("SCRAM MakeInterface::exec(): Unable to run gmake ...  %s" % e)
