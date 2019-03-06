from SCRAM.Core.SiteConfig import SiteConfig


def cmd_config(args):
    conf = SiteConfig()
    if len(args) == 0:
        return conf.dump()
    key = args[0]
    value = ''
    if '=' in key:
        key, value = key.split('=', 1)
    if value:
        return conf.set(key, value)
    value = conf.get(key)
    if value is None:
        return False
    return conf.dump(key)
