#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Entry point of program when not installed.
main.py is 'unhappy' when it is called from inside the module.
"""

from SCRAM.main import entry_point

if __name__ == '__main__':
    entry_point()
