import os


def get_safename(path):
    return path.replace(os.path.sep, "_")
