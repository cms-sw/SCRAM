import shutil
from os import path, makedirs


def fixpath(malformed_path):
    """
    Fixes path with '../' ,'////' and './' .
    :return:
    """
    return path.normpath(malformed_path)


def adddir(path_to_dir):
    makedirs(fixpath(path_to_dir), 755)
    return


def copydir(src, dst):
    """
    :param src:
    :param dst: destination directory. It
    :return:
    """
    shutil.copytree(src, dst, symlinks=True, ignore=None)


def copyfile(src, dst):
    shutil.copy2(src, dst)


def getfilelist():
    # TODO
    return
