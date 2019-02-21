from os import environ
from os.path import join
if 'LOCALTOP' in environ:
    __path__.insert(0, join(environ['LOCALTOP'], 'config', 'SCRAM', 'Plugins'))
