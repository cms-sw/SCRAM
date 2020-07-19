import shutil
from os import makedirs, walk, path
from os.path import exists
from SCRAM import die
import logging


def fixpath(malformed_path):
    """
    Fixes path with '../' ,'////' and './' .
    :return:
    """
    return path.normpath(malformed_path)


def adddir(path_to_dir):
    logging.debug("Creating directory {0}".format(path_to_dir))
    if exists(path_to_dir):
        logging.debug("Directory exists {0}".format(path_to_dir))
        return
    try:
        logging.debug("Creating directory {0}".format(path_to_dir))
        makedirs(path.normpath(path_to_dir), 0o755)
    except IOError as e:
        die("cannot make directory {0} . {1}".format(path_to_dir, str(e)))


def copydir(src, dst):
    """
    :param src:
    :param dst: destination directory. It shouldn't exists.
    :return:
    """
    logging.debug("Copy from " + "'{0}'".format(src) + " to " + "'{0}'".format(dst))
    try:
        shutil.copytree(src, dst, symlinks=True, ignore=None)
    except IOError as e:
        die("ERROR: failed to copy directory from {0} to {1}. ".format(src, dst) + str(e))


def copyfile(src, dst):
    logging.debug("Copy from " + "'{0}'".format(src) + " to " + "'{0}'".format(dst))
    try:
        shutil.copy2(src, dst)
    except IOError as e:
        die("ERROR: failed to copy file from {0} to {1}. ".format(src, dst) + str(e))


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
        die("ERROR: Can not open directory for reading: {0}".format(dir_path) + str(e))

    return rez_list
