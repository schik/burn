Burn
========
Burn (fka GSburn.app) is a GNUstep based CD burning program.
It serves as front-end for Joerg Schilling's cdrtools
(cdrecord and mkisofs), cdrdao, and cdparanoia.
You will no longer need to remember ugly command line parameters
for cdrecord or write shell scripts (I know, I know. The purists
among us decline the usage of any graphical tool. But as a purist
you didn't download this application in the first place and thus
won't read this anyway ;-).
With Burn you compile your CD by point-and-click operation
and save your projects for later reuse. Burn will hide as
many settings as possible from you, thus making it very easy and
user-friendly to create your own CDs.

Burn has now reached version 0.6.0.


Platforms
=========
Burn is developped and tested on a x86 PC running GNU/Linux.
Being a GNUstep application, it may be portable to other platforms
where GNUstep is available (and the external tools, of course).


Requirements
============
Before you install Burn, you must make sure that the following
software is installed on your system. Otherwise you might not even be
able to compile Burn.


GNUstep
-------
Of course, Burn needs a GNUstep (www.gnustep.org) environment
to run. It has been developed and tested in the following environment:

gnustep-make 1.23
gnustep-base 1.23
gnustep-gui  0.21
gnustep-back 0.21

Burn will most probably not run with older versions of GNUstep,
in particular -gui.


GWorkspace.app
--------------
For adding files and directories you will need an appropriate "file manager"
being able to communicate with Burn via DnD. Currently, there is only
GWorkspace.app. Any version from on 0.6.0 should do.
Install GWorkspace.app according to its instructions.


CDPlayer
------------
You also need CDPlayer to use Burn. This is because Burn
uses the AudioCD.bundle included in CDPlayer to read an audio
CD's TOC. Burn now also relies on CDPlayer for adding audio CD tracks to a CD
description either via DnD or using the new services.
CDPlayer can be downloaded at:

https://github.com/schik/cdplayer

Unpack the tar ball and do:

> make
> make install


Other software
==============
As mentioned above, Burn uses several external tools to
actually accomplish the tasks of ripping audio CDs or burning CDs.
These must be installed from other sources as they are not part
of Burn.

cdrtools
--------
The cdrtools package contains the programs
_cdrecord_, _mkiofs_ and _cdparanoia_. They are supported by
the respective bundles _CDrecord.burntool_, _MkIsoFs.burntool_
and _CDparanoia.burntool_.
Burn 0.6 has been tested with the following versions (Note,
that other versions may work, too, but were not tested.):
 
cdrecord  (www.fokus.gmd.de/usr/schilling/cdrecord.html)
	Cdrecord-ProDVD-ProBD-Clone 3.00

mkisofs   (www.fokus.gmd.de/usr/schilling/cdrecord.html)
	3.00

cdparanoia III rel. 10.2.  	(www.xiph.org/paranoia)

Note, that Burn is tested with the _original_ programs from the
cdrtools suite. Most Linux distros today come with the cdrkit instead.

cdrkit
------
_cdrkit_ is a replacement for the cdrtools package. The programs
in the package are called _wodim_ and _genisoimage_. cdrecord and
mkisofs are symbolic links to these programs! cdrkit (especially wodim)
uses slightly different command line arguments. In particular, media
detection does not work reliably, if at all.
wodim and genisoimage can be used with the bundles _CDrecord_ and
_MkIsoFs_.
If you want to use cdrkit (wodim), open the settings dialog and set
the program path accordingly. You have to turn on the compatibility mode,
too, to run wodim with correct parameters.

cdrskin
-------
There exists another program that claims to be compatible to cdrecord,
_cdrskin_. I have not tested cdrskin thoroughfully, but it seems as if
it is a suitable drop-in replacement for the original cdrecord program.
At least it understands the same parameters and prints the same output.
Thus, it can be used with the _CDrecord_ bundle.
If you want to use it, open the settings dialog and set the program path
accordingly. You do not have to turn on the compatibility mode.

cdrdao
------
An alternative writing backend is cdrdao. cdrecord may be replaced
by this program. Note, that cdrdao may lack some of cdrecord's features.
Burn 0.6 has been tested with the following version (Note,
that other versions may work, too, but were not tested.):

cdrdao
	1.2.2


Installation
============
Before you install Burn you should deinstall any old version of GSburn.app.
This is because Burn is the replacement for GSburn.app.
They may coexist, but you want need GSburn.app anymore.


After installing the above stuff simply do

> tar xzf burn-xxx.tar.gz
> cd burn-xxx
> make
> make install

This will install everything needed to run Burn except
the external tools (see above).

If you want the documentation to be created, call

> make doc=yes.

This will create one additional directory, DeveloperDoc,
containing documentation on the classes, protocols, functions
and so on. However, this feature is far from being finished, yet.


HOWTO
=====
Howto what? Burn is designed to be simple, easy to use and intuitive ;-)
Seriously, check the online help for further assistance.


Disclaimer
==========
You use Burn at your own risk. I cannot be held responsible for
any damage to your hardware, for spoiled raw media or for loss of data.


Contact
=======
For bug reports or feature requests contact the author:

Andreas Schik <andreas@schik.de>

Burn can be found at https://github.com/schik/burn
