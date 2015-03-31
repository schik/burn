Burn.app
========
Burn.app (fka GSburn.app) is a GNUstep based CD burning program.
It serves as front-end for Joerg Schilling's cdrtools
(cdrecord and mkisofs), cdrdao, and cdparanoia.
You will no longer need to remember ugly command line parameters
for cdrecord or write shell scripts (I know, I know. The purists
among us decline the usage of any graphical tool. But as a purist
you didn't download this application in the first place and thus
won't read this anyway ;-).
With Burn.app you compile your CD by point-and-click operation
and save your projects for later reuse. Burn.app will hide as
many settings as possible from you, thus making it very easy and
user-friendly to create your own CDs.

Burn.app has now reached version 0.5.0.


Platforms
=========
Burn.app is developped and tested on a x86 PC running GNU/Linux.
Being a GNUstep application, it may be portable to other platforms
where GNUstep is available (and the external tools, of course).


Requirements
============

Before you install Burn.app, you must make sure that the following
software is installed on your system. Otherwise you might not even be
able to compile Burn.app.


GNUstep
-------
Of course, Burn.app needs a GNUstep (www.gnustep.org) environment
to run. It has been developed and tested in the following environment:

gnustep-make 1.23
gnustep-base 1.23
gnustep-gui  0.21
gnustep-back 0.21

Burn.app will most probably not run with older versions of GNUstep,
in particular -gui.


GWorkspace.app
--------------
For adding files and directories you will need an appropriate "file manager"
being able to communicate with Burn.app via DnD. Currently, there is only
GWorkspace.app. Any version from on 0.6.0 should do.
Install GWorkspace.app according to its instructions.


CDPlayer.app
------------
You also need CDPlayer.app to use Burn.app. This is because Burn.app
uses the AudioCD.bundle included in CDPlayer.app to read an audio
CD's TOC. Burn now also relies on CDPlayer for adding audio CD tracks to a CD
description either via DnD or using the new services.
CDPlayer.app can be downloaded at:

http://sourceforge.net/project/showfiles.php?group_id=61565&release_id=132392

You need at least version 0.4.0 of CDPlayer.app.

More recent versions may be on CVS:
cvs -d:pserver:anonymous@cvs.gsburn.sourceforge.net:/cvsroot/gsburn login
password is empty
cvs -z3 -d:pserver:anonymous@cvs.gsburn.sourceforge.net:/cvsroot/gsburn co CDPlayer

Unpack the tar ball and do:

> make
> make install


Other software
==============

cdrtools
--------
As mentioned above, Burn.app uses several external tools to
actually accomplish the tasks of ripping audio CDs or burning CDs.
The package does _not_ contain these external tools, namely
cdrecord, mkiofs, and cdparanoia. These must be acquired and
installed separately.
Burn.app 0.5 has been tested with the following versions (Note,
that other versions may work, too, but were not tested.):
 
cdrecord  (www.fokus.gmd.de/usr/schilling/cdrecord.html)
	Cdrecord-ProDVD-ProBD-Clone 3.00

mkisofs   (www.fokus.gmd.de/usr/schilling/cdrecord.html)
	3.00

cdparanoia III rel. 10.2.  	(www.xiph.org/paranoia)

Note, that Burn.app is tested with the _original_ programs from the
cdrtools suite. Most Linux distros today come with the cdrkit instead,
containing wodim and genisoimage. cdrecord and mkisofs are only symbolic
links to these programs! To my knowledge, cdrkit (especially wodim)
uses slightly different command line arguments. In particular, media
detection does not work reliably, if at all.
If you want to use cdrkit (wodim) you may set the parameter "Toolkit"
in the "CDrecordParameters" dictionary of the user defaults to "cdrkit"
before running Burn. There is no GUI element, yet, to change this.


cdrdao
------
An alternative writing backend is cdrdao. cdrecord may be replaced
by this program. Note, that cdrdao may lack some of cdrecord's features.
Burn.app 0.5 has been tested with the following version (Note,
that other versions may work, too, but were not tested.):

cdrdao
	1.2.2


Installation
============

Before you install Burn.app you should deinstall any old version of GSburn.app.
This is because Burn.app is the replacement for GSburn.app.
They may coexist, but you want need GSburn.app anymore.


After installing the above stuff simply do

> tar xzf burn-xxx.tar.gz
> cd burn-xxx
> make
> make install

This will install everything needed to run Burn.app except
the external tools (see above).

The cdrdao backend bundle is no longer part of the release archive. If you
ish to use cdrdao for burning, dowload the bundle's source code separately
from SF and install it according to its instructions.

If you want the documentation to be created, call

> make doc=yes.

This will create one additional directory, DeveloperDoc,
containing documentation on the classes, protocols, functions
and so on. However, this feature is far from being finished, yet.


HOWTO
=====

Howto what? Burn.app is designed to be simple, easy to use and intuitive ;-)
Seriously, check the online help for further assistance.


Disclaimer
==========

Burn.app is in a beta state and not yet stable. You use it at
your own risk. I cannot be made responsible for any damage to your
hardware or for spoiled raw media.


Future plans
============

Burn.app may move towards using libburn and libisofs (http://icculus.org/burn).
The cdrtools backends will then be only optional tools that can be installed
additionally.
One reason for this are the above mentioned problems with cdrecord, another is
the somewhat arrogant attitude of Schily wrt helping other people with their
problems and wrt to the 'brokenness' of other tools than his cdrtools.
There are technical reasons, too. Using a library seems somewhat easier than
starting and communicationg with external programs.


Contact
=======

For bug reports or feature requests contact the author:

Andreas Schik <andreas@schik.de>

Burn.app can be found at https://github.com/schik/burn
