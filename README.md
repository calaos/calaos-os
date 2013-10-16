calaos-os
=========

---

calaos-os contains the scripts needed to build Calaos images. The buildsystem is using OpenEmbedded and the scripts comes from the great Angstrom build system.


Supported boards
----------------

The following hardware are supported by the Calaos team:
- Mele A1000 / Mele A2000
- Raspberry Pi
- Intel Atom based board
- Cubieboard

Other hardware may be supported but only those one are heavily tested by us. Feel free to try to port to a new hardware, and come to check with us for all the details.

How to build
------------

This is a quick howto for building a fresh Calaos image.

First you need to configure which machine you want to build to:
```bash
./build.sh config raspberrypi
```

The script will download all needed recipes from various places. When it's finished you can start a build by using:
```bash
./build.sh build
```

You will find the images in build/tmp-calaos-eglibc/deploy/images

