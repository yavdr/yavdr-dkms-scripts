#!/bin/bash -e

# call with repo name and make sure all files exist
#
# - patches
# - template
# - repo
#

###########
# make sure linux-headers is installed
# and adapt to the kernel you like to compile for
########################

update-linux-media () {
echo "linux-media: Update started"
# BEWARE this is more a notepad to remamber what has to be done, if it works you are lucky !!!
if [ -d updates/linux-media -a -d updates/media_build ]; then
    cd updates/linux-media
    git pull
    cd ..
    cd media_build
    git pull
    cd ..
else
    cd updates/
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux-2.6.git linux-media
    cd linux-media
    git remote add linuxtv git://linuxtv.org/media_tree.git
    git remote update
    git checkout -b v3.3 remotes/linuxtv/staging/for_v3.3
    cd ..
    git clone git://linuxtv.org/media_build.git
fi

cd media_build/linux
make tar DIR=../../linux-media &> /dev/null
make untar &> /dev/null
cd ..
rm -rf ../../repositories/linux-media
mkdir -p ../../repositories/linux-media
tar c * --exclude=".hg" --exclude ".git" | tar x -C ../../repositories/linux-media
cd ../linux-media
VERSION=git`git rev-list --all | wc -l`
cd ../media_build
VERSION=$VERSION.`git rev-list --all | wc -l`
cd ../..
git rev-list --max-count=1 HEAD > repositories/linux-media.revision
echo $VERSION > repositories/linux-media.version
echo "linux-media: Update ended. Now: $VERSION"
}

update-s2-liplianin () {
cd updates
echo "s2-liplianin: Update started"
if [ -d s2-liplianin ]; then
    cd s2-liplianin
    hg pull
    hg update
    cd ..
else
    hg clone http://mercurial.intuxication.org/hg/s2-liplianin-ahead s2-liplianin
fi
rm -rf ../repositories/s2-liplianin
tar c s2-liplianin --exclude=".hg" --exclude ".git" | tar x -C ../repositories/
VERSION=`hg identify -n s2-liplianin | cut -d'+' -f1`
echo $VERSION > ../repositories/s2-liplianin.version
hg id -i s2-liplianin > ../repositories/s2-liplianin.revision
cd ..
echo "s2-liplianin: Update ended. Now: $VERSION"
}

KERNEL=3.0.0-14-generic
RELEASE=oneiric
#KERNEL=2.6.38-12-generic
#RELEASE=natty
if [ -z "$KERNEL" ]; then
    if [ ! -z "$2" ]; then
    	KERNEL="$2"
    else
        KERNEL="`uname -r`"
    fi
fi

case $1 in
   s2-liplianin|linux-media|linux-media-tbs)
           REPO=$1
	   ;;
   clean)
           rm -rf tmp.* &> /dev/null || /bin/true
           rm -rf temp-build &> /dev/null || /bin/true
           rm dkms.conf.* &> /dev/null || /bin/true

           exit 0
           ;;
   update)
           echo -n "BEWARE: the code to do this has more note pad quality. Stop here "
           read BLA
           mkdir -p updates
           update-linux-media
           update-s2-liplianin
           exit 0
           ;;
   *)
           exit 1
           ;;
esac

VERSION=0~`/bin/date +%0Y%0m%0d`.$(cat repositories/$REPO.version)~$RELEASE
if find patches/$REPO/*patch &> /dev/null ; then
PATCHES=( `find patches/$REPO/* -name '*.patch' | tac` )
fi

if [ -e "config-$REPO" ]; then
    cp config-$REPO repositories/$REPO/v4l/.config
fi

# generate changelog
cat templates/changelog | sed "s/RELEASE/$RELEASE/" | sed "s/DEBEMAIL/$DEBEMAIL/" | sed "s/DEBFULLNAME/$DEBFULLNAME/" > templates/$REPO/debian/changelog

# generate dkms.conf
cat <<EOF > dkms.conf.$REPO
PACKAGE_NAME=$REPO
PACKAGE_VERSION=$VERSION
AUTOINSTALL=y
MAKE[0]="make -j5 VER=\$kernelver"
EOF

if [ "$REPO" = "linux-media-tbs" ]; then 
   echo "CLEAN=\"make clean; if arch | grep -q 64 ; then ./v4l/tbs-x86_64.sh ; elif  echo \$kernelver | grep -q ^3\..* ; then  ./v4l/tbs-x86_r3.sh ; else ./v4l/tbs-x86.sh ; fi\"" >> dkms.conf.$REPO
fi

PATCHCOUNT=0
for PATCH in ${PATCHES[@]} ; do
echo "PATCH[$PATCHCOUNT]=`basename $PATCH`" >> dkms.conf.$REPO
if [ -f "${PATCH}.match" ]; then
    echo "PATCH_MATCH[$PATCHCOUNT]=\"`cat ${PATCH}.match`\"" >> dkms.conf.$REPO
fi
PATCHCOUNT=$(( $PATCHCOUNT + 1 ))
done

# temporary build
if [ ! -d temp-build ]; then
    cp -r repositories/$REPO temp-build
    for PATCH in ${PATCHES[@]} ; do
        if [ ! -f "${PATCH}.match" ] || echo "$KERNEL" | egrep -q "`cat ${PATCH}.match`"; then
            echo "Patching $PATCH ... "
            patch -d temp-build -p1 < $PATCH
        fi
    done
    if [ "$REPO" = "linux-media-tbs" ]; then
       cd temp-build
       if arch | grep -q 64 ; then
          ./v4l/tbs-x86_64.sh
       elif echo $KERNEL | grep -q "^3\..*" ;then
          ./v4l/tbs-x86_r3.sh
       else
          ./v4l/tbs-x86.sh
       fi
       cd ..
    fi

    make -j5 -C temp-build KERNELRELEASE=$KERNEL VER=$KERNEL
fi

cd temp-build

# determine module names and paths from temporary build
i=0
for f in `find -name *.ko`; do
    M=`basename $f .ko`
    if [ "$M" = "v4l2-compat-ioctl32" ]; then 
       COMPAT=yes
    else
       echo "BUILT_MODULE_NAME[$i]=$M" >> ../dkms.conf.$REPO
       echo "BUILT_MODULE_LOCATION[$i]=`dirname $f`" >> ../dkms.conf.$REPO
       echo "DEST_MODULE_LOCATION[$i]=/updates/dkms" >> ../dkms.conf.$REPO
       ((i=i+1))
    fi 
done

if [ "$COMPAT" = "yes" ]; then 
   echo "if arch | grep -q 64 ; then" >> ../dkms.conf.$REPO
   echo "BUILT_MODULE_NAME[$i]=v4l2-compat-ioctl32" >> ../dkms.conf.$REPO
   echo "BUILT_MODULE_LOCATION[$i]=`dirname $f`" >> ../dkms.conf.$REPO
   echo "DEST_MODULE_LOCATION[$i]=/updates/dkms" >> ../dkms.conf.$REPO
   echo "fi" >> ../dkms.conf.$REPO
fi
cd ..

# create temporary s ource and dkms trees
srctree=`mktemp -d --tmpdir=$PWD`
dkmstree=`mktemp -d --tmpdir=$PWD`
cp /var/lib/dkms/dkms_dbversion $dkmstree
#trap "rm -rf $srctree $dkmstree" 0 1 2 3 4 5 6 7 8 10 11 12 13 14 15

# copy to srctree (without .hg/)
D="$srctree/${REPO}-$VERSION"
mkdir -p $D
cp -r repositories/${REPO}/* $D

# modules are not versioned properly, so kill the versions to disable dkms'
# version comparison
find $D -name '*.c' | xargs sed -i '/^MODULE_VERSION\>/d'

cp dkms.conf.$REPO $D/dkms.conf
mkdir $D/patches

if find patches/$REPO/*patch &> /dev/null; then
  cp patches/$REPO/*.patch $D/patches
fi

cp -r templates/$REPO $D/${REPO}-dkms-mkdsc
cp -r templates/$REPO $D/${REPO}-dkms-mkdeb

# register to dkms
dkms --sourcetree $srctree --dkmstree $dkmstree add -m ${REPO} -v $VERSION -k $KERNEL
dkms --sourcetree $srctree --dkmstree $dkmstree build -m ${REPO} -v $VERSION -k $KERNEL
# build debian source package
dkms --sourcetree $srctree --dkmstree $dkmstree mkdsc -m ${REPO} -v $VERSION -k $KERNEL
cp $dkmstree/${REPO}/$VERSION/dsc/* ./packages/dsc/

# mkdeb
dkms --sourcetree $srctree --dkmstree $dkmstree mkdeb -m ${REPO} -v $VERSION -k $KERNEL
cp $dkmstree/${REPO}/$VERSION/deb/* ./packages/deb/

# upload to ppa
#dput ppa:yavdr/main ./packages/dsc/$REPO-dkms_$VERSION*.changes
