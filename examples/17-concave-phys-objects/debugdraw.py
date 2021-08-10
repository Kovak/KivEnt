import itertools
from math import ceil, sqrt
import os


def gv(*groups, **kwargs):
    pdf = kwargs.get("pdf", True)
    single = kwargs.get("single", False)
    closed = kwargs.get("closed", True)
    f = open("/tmp/ee.plt", "w")

    minr, maxr = 999999, -9999999
    for group in groups:
        for path in group:
            for vert in path:
                for coord in vert:
                    minr = min(minr, coord)
                    maxr = max(maxr, coord)

    numplots = len(groups)
    inrow = int(ceil(sqrt(numplots)))
    numrows = int(ceil(float(numplots)/inrow))

    if pdf:
        f.write('set terminal pdfcairo font "arial, 9" size 30cm,30cm \n')
        f.write('set output "/tmp/ee.pdf"\n')
    f.write("set multiplot layout %s, %s\n"%(numrows, inrow))
    f.write("set size ratio -1\n")
    f.write("set xrange[%s:%s]\n"%(minr-1, maxr+1))
    f.write("set yrange[%s:%s]\n"%(minr-1, maxr+1))
    for group in groups:
        f.write("plot '-' u 1:2:3:4 w vectors\n")
        
        for vs in group:
            for (fx, fy),(tx, ty) in (zip(vs, vs[1:] + vs[:1]) if closed else zip(vs[:-1], vs[1:])):
                f.write("%s %s %s %s\n"%(fx, fy, (tx-fx), (ty-fy)))
        f.write("e\n")

    f.close()
    os.system("gnuplot /tmp/ee.plt -persist")


if __name__ == '__main__':
    gv([[(-85.18263244628906, -194.4100341796875), (48.45586013793945, -193.8280029296875), (45.539608954794595, -194.4100341796875), (1.3924713134765625, -203.22100830078125)],
        [(-80, -80), (-80, 80), (80, 80), (80, -80)]],
        [
            [(1,2), (2,3), (3,4), (4,5)],
            []
        ]
            , closed=False)
