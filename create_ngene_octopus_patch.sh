#!/bin/bash

# create tmp dir
if [ ! -d tmp ]; then
  mkdir tmp;
fi

# load driver
if [ -d repositories/ngene-octopus-test ]; then
  cd repositories/ngene-octopus-test
  git pull
  cd ../..
else
  cd repositories/
  hg clone http://linuxtv.org/hg/~endriss/ngene-octopus-test
  cd ..
fi

# remove old directories
rm -rf tmp/linux-media
rm -rf tmp/linux-media-patched

# copy media tree
cp -r repositories/linux-media tmp/linux-media
cp -r repositories/linux-media tmp/linux-media-patched

# patch it!

# remove old
rm -Rf tmp/linux-media-patched/linux/drivers/media/dvb/{ddbridge,ngene}
rm -Rf tmp/linux-media-patched/linux/drivers/staging/media/cxd2099
rm -Rf tmp/linux-media-patched/linux/drivers/staging/cxd2099

# copy new
cp -r repositories/ngene-octopus-test/linux/drivers/media/dvb/{ddbridge,ngene} tmp/linux-media-patched/linux/drivers/media/dvb/
cp -r repositories/ngene-octopus-test/linux/drivers/staging/cxd2099 tmp/linux-media-patched/linux/drivers/staging/media/
cp repositories/ngene-octopus-test/linux/drivers/media/dvb/frontends/tda18212dd* tmp/linux-media-patched/linux/drivers/media/dvb/frontends/
cp repositories/ngene-octopus-test/linux/drivers/media/dvb/frontends/stv0367dd* tmp/linux-media-patched/linux/drivers/media/dvb/frontends/

# patches
patch -dtmp/linux-media-patched/ -p0 < patches/ngene-octopus-test/stv0367dd-tda18212dd.frontend-kconfig.diff
patch -dtmp/linux-media-patched/ -p0 < patches/ngene-octopus-test/stv0367dd-tda18212dd.frontend-makefile.diff 

cd tmp/
diff -Nur linux-media linux-media-patched > ../patches/linux-media/0001-add-drivers-stv0367dd-tda18212dd-cxd2099.patch
cd ..
