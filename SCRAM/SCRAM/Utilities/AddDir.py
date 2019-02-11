import shutil
from os import makedirs, walk, path


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
    :param dst: destination directory. It shouldn't exists.
    :return:
    """
    shutil.copytree(src, dst, symlinks=True, ignore=None)


def copyfile(src, dst):
    shutil.copy2(src, dst)


def getfilelist(dir_path):
    """
    Returns list of files in relative path from directory.
    :param dir_path: Directory path.
    :return:
    """
    rez_list = []
    for root, dirs, files in walk(dir_path, topdown=False):
        for name in files:
            rez_list.append(path.join(root.replace(dir_path, ""), name))
    return rez_list
