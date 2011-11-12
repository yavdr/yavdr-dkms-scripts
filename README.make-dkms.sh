
Short description
-----------------

Requirements: linux-headers-.... , 
              mercurial, git (for update the repos and getting the hg version), 
              gcc etc,
              dput,
              gnupg-agent,
              patched dkms

Directory structure:
make-dkms.sh
   repositories/
   patches/
   templates/

below this directories: the repo name (s2-liplianin or v4l-dvb)
in this directories: 
   repositories: the checkout of the repo's
   patches: patches you want to apply in the dkms package
   templates: dkms mkdeb/mkdsc template (mkdsc and mkdeb is the same)

call make-dkms.sh <name of the repo> will make test build, extract 
the module names, and build the dkmsconf for it. Then the dkms package will be created
and uploaded to launchpad.

call make-dkms.sh clean to clean up after successfull build or when you like

call make-dkms.sh update to update s2-liplianin and v4l-dvb repositories from remote.
For v4l-dvb it might be needed to change to the latest for.... branch of media_tree in order 
to get latest code. 

If you want to upload packages to ppa, some things need to be configured:
- comment out the dput to really upload
- make sure gpg key is configured for being able to sign the package
- make sure you are using a bugfixed version of dkms (i.e. not the ubuntu version, but the yavdr version) 
- make sure you export DEBFULLNAME and DEBEMAIL before starting the script (i.e. adding the export to your .profile)

The whole script is intended to simplify creating a recent dvb driver package and is in some parts based 
on a script created by Martin Pitt, which he has published few years back. It's not intended for 
newbies to create dkms magically. Patches are welcome, question only if you know what you are doing. 

tbs drivers are updated by downloading and unpacking the driver tarball into the repository folder and update the version manually. 

Good Luck ! ;) 
