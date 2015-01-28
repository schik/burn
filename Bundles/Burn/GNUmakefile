include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Burn
BUNDLE_EXTENSION = .burntool

Burn_RESOURCE_FILES = iconBurn.tiff

Burn_OBJC_FILES = \
	BurnController.m

Burn_HEADERS = \
	BurnController.h

Burn_PRINCIPAL_CLASS = \
	BurnController

ADDITIONAL_OBJCFLAGS = -Wall

LIBBURN_INCLUDEDIR = /usr/local/include
ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/ -I$(LIBBURN_INCLUDEDIR)
BUNDLE_LIBS += -lburn

Burn_LANGUAGES=English German French
Burn_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
