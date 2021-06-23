import logging


class TemplateStash():
    """
    A specific data structure needed to resolve dependencies while traversing directory
    """

    def __init__(self):
        self._stash = [{}]
        self._index = 0

    def pushstash(self):
        self._stash.append({})
        self._index += 1

    def popstash(self):
        if self._index > 0:
            self._stash.pop()
            self._index -= 1
        else:
            logging.info("Tried to pop empty list")

    def stash(self, stash=None):
        # TODO needs revision
        if stash:
            self._stash = [stash]
            self._index = 0
        else:
            return self

    def set(self, key, value):
        if not key:
            return
        self._stash[self._index][key] = value

    def get(self, key, default=""):
        if not key:
            return default
        for i in range(self._index, -1, -1):
            if key in self._stash[i]:
                return self._stash[i][key]
        return default  # if not found, return empty string
