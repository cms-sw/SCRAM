import SCRAM
from os.path import exists, join
from os import environ, makedirs, execv


def create_productstores(area):
    from SCRAM.BuildSystem.BuildFile import BuildFile
    sym = None
    if area.symlinks() > 0:
        from SCRAM.Core.ProdSymLinks import ProdSymLinks
        sym = ProdSymLinks()
    location = area.location()
    bf = BuildFile(location)
    bf.parse(join(area.config(), 'BuildFile.xml'))
    arch = area.arch()
    for store in bf.contents['PRODUCTSTORE']:
        storename = None
        if ('type' in store) and (store['type'] == 'arch'):
            if ('swap' in store) and (store['swap'] == 'true'):
                storename = join(store['name'], arch)
            else:
                storename = join(arch, store['name'])
        else:
            storename = store['name']
        if not exists(storename):
            if not sym:
                makedirs(join(location, storename), 0o755)
            else:
                sym.mklink(location, storename)
    src = join(location, area.sourcedir())
    if not exists(src):
        makedirs(src)
    tmp = join(area.tmp(), arch)
    if not sym:
        tmp = join(location, tmp)
        if not exists(tmp):
            makedirs(tmp, 0o755)
    else:
        sym.mklink(location, tmp)
    return


def remote_versioncheck(area):
    sversion = area.scram_version()
    if not sversion:
        SCRAM.scramerror("Unable to determine SCRAM version used to config. remote area.")
    spawnversion(sversion)


def spawnversion(newversion='V2_99_99'):
    if SCRAM.VERSION.split("_", 1)[0] != newversion.split("_", 1)[0]:
        environ['SCRAM_VERSION'] = newversion
        execv(SCRAM.BASEPATH + "/common/scram", argv)


def cmsos():
    e, os = SCRAM.run_command('cmsos')
    if e:
        return None
    return '_'.join(os.split('_', 2)[:2])
