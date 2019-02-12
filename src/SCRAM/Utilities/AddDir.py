import shutil
from os import makedirs, walk, path
import sys
import logging


log = logging.getLogger(__name__)


def fixpath(malformed_path):
    """
    Fixes path with '../' ,'////' and './' .
    :return:
    """
    return path.normpath(malformed_path)


def adddir(path_to_dir):
    try:
        makedirs(fixpath(path_to_dir), 755)
    except IOError as e:
        print ("ERROR: failed to create directory directory {0}"
               .format(path_to_dir), e)
        sys.exit(1)


def copydir(src, dst):
    """
    :param src:
    :param dst: destination directory. It shouldn't exists.
    :return:
    """
    try:
        shutil.copytree(src, dst, symlinks=True, ignore=None)
    except IOError as e:
        print ("ERROR: failed to copy directory from {0} to {1}. "
               .format(src, dst), e)
        sys.exit(1)


def copyfile(src, dst):
    try:
        shutil.copy2(src, dst)
    except IOError as e:
        print ("ERROR: failed to copy file from {0} to {1}. "
               .format(src, dst), e)
        sys.exit(1)


def getfilelist(dir_path):
    """
    Returns list of files in relative path from directory.
    :param dir_path: Directory path.
    :return:
    """
    rez_list = []
    try:
        for root, dirs, files in walk(dir_path, topdown=False):
            for name in files:
                rez_list.append(path.join(root.replace(dir_path, ""), name))
    except IOError as e:
        print ("ERROR: failed to list path: {0}. ".format(dir_path), e)
        sys.exit(1)

    return rez_list
