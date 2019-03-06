import SCRAM
from SCRAM.Core.ProjectDB import ProjectDB
from argparse import ArgumentParser
from os import environ
from os.path import isdir


def process(args):
    parser = ArgumentParser(add_help=False)
    parser.add_argument('-s', '--show',
                        dest='show',
                        action='store_true',
                        default=False,
                        help='Show all the external databases linked in to your SCRAM db')
    parser.add_argument('-l', '--link',
                        dest='link',
                        type=str,
                        default=None,
                        help='Link/Add an external scram db <path> in to local scram db.')
    parser.add_argument('-u', '--unlink',
                        dest='unlink',
                        type=str,
                        default=None,
                        help='Unlink/Remove an already linked external db <path> from the local scram db.')
    opts, args = parser.parse_known_args(args)
    db = ProjectDB()
    if opts.link:
        environ['SCRAM_LOOKUPDB'] = environ['SCRAM_LOOKUPDB_WRITE']
        if isdir(opts.link):
            if not db.link(opts.link):
                SCRAM.scramerror("Can not link to SCRAM-DB. No such directory: %s" % opts.link)
            else:
                SCRAM.printmsg("Current SCRAM database: %s" % environ['SCRAM_LOOKUPDB'])
                SCRAM.printmsg("Linked \"%s\" to current SCRAM database." % opts.link)
    elif opts.unlink:
        environ['SCRAM_LOOKUPDB'] = environ['SCRAM_LOOKUPDB_WRITE']
        if db.unlink(opts.unlink):
            SCRAM.printmsg("Current SCRAM database: %s" % environ['SCRAM_LOOKUPDB'])
            SCRAM.printmsg("Unlinked \"%s\" from current SCRAM database." % opts.unlink)
    else:
        SCRAM.printmsg("Current SCRAM database: %s" % environ['SCRAM_LOOKUPDB'])
        links = db.listlinks()
        flag = False
        for db_type in ["local", "linked"]:
            if db_type not in links or not links[db_type]:
                continue
            flag = True
            msg = "The following SCRAM databases are linked "
            if 'local' == db_type:
                msg += "directly:"
            else:
                msg += "in-directly:"
            SCRAM.printmsg(msg)
            for extdb in links[db_type]:
                SCRAM.printmsg("\t%s" % extdb)
            SCRAM.printmsg("")
        if not flag:
            SCRAM.printmsg("There are no SCRAM databases linked.")
    return True
