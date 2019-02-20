# -*- coding: utf-8 -*-
from pytest import raises
import pytest
from src.SCRAM.BuildSystem.TemplateStash import TemplateStash

parametrize = pytest.mark.parametrize


class TestTemplateStash(object):

    # @parametrize('versionarg', ['-V', '--version'])
    def test_class(self):
        def assert_size():
            assert len(stash._stash) == stash._index + 1

        stash = TemplateStash()
        assert_size()

        stash.set("key1", 1)
        stash.set("key2", 2)
        assert_size()

        assert stash.get("key1") == 1
        assert stash.get("key2") == 2
        assert stash._index == 0
        stash.pushstash()

        stash.set("key1", 11)
        assert stash.get("key1") == 11
        assert stash.get("key2") == 2
        assert stash.get("empty_key") == ""
        assert stash._index == 1
        assert_size()

        stash.popstash()
        assert_size()
        assert stash.get("key1") == 1
        assert stash.get("key2") == 2
        assert stash.get("empty_key") == ""
