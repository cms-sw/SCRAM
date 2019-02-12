# -*- coding: utf-8 -*-
from pytest import raises

# The parametrize function is generated, so this doesn't work:
#
#     from pytest.mark import parametrize
#
import pytest
import sys
parametrize = pytest.mark.parametrize

from src import metadata
from src.main import main


class TestMain(object):
    @parametrize('helparg', ['-h', '--help'])
    def test_help(self, helparg, capsys):
        with raises(SystemExit) as exc_info:
            main(['progname', helparg])
        out, err = capsys.readouterr()
        # Should have printed some sort of usage message. We don't
        # need to explicitly test the content of the message.
        assert 'usage' in out
        # Should have used the program name from the argument
        # vector.
        assert 'progname' in out
        # Should exit with zero return code.
        assert exc_info.value.code == 0

    @parametrize('versionarg', ['-V', '--version'])
    def test_version(self, versionarg, capsys):
        with raises(SystemExit) as exc_info:
            main(['progname', versionarg])
        out, err = capsys.readouterr()
        # bug in capturing output between python versions
        rez = err if sys.version_info < (3, 0) else out
        # Should print out version.
        assert rez == '{0} {1}\n'.format(metadata.project, metadata.version)
        # Should exit with zero return code.
        assert exc_info.value.code == 0
