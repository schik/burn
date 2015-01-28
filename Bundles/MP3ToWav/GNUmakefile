include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = MP3ToWav
BUNDLE_EXTENSION = .burntool

MP3ToWav_RESOURCE_FILES = iconMP3ToWav.tiff

MP3ToWav_OBJC_FILES = \
	MP3ToWavController.m \
	PlayBuffer.m \
	MadFunctions.m

MP3ToWav_HEADERS = \
	MP3ToWavController.h \
	PlayBuffer.h \
	MadFunctions.h

MP3ToWav_PRINCIPAL_CLASS = \
	MP3ToWavController

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/
BUNDLE_LIBS += -lao -lmad

MP3ToWav_LANGUAGES=English German French
MP3ToWav_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
