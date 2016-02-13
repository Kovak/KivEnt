import re
import os
import unicodedata


def name_from_tile(tile):
    return slugify('{}-{}'.format(tile.parent.name, tile.gid))


def name_from_source(source):
    filename = os.path.split(source)[1]
    return os.path.splitext(filename)[0]


def slugify(value):
    value = unicode(value)
    value = unicodedata.normalize('NFKD', value).encode('ascii', 'ignore').decode('ascii')
    value = re.sub('[^\w\s-]', '', value).strip().lower()
    value = re.sub('[-\s]+', '-', value)
    return value.encode()
