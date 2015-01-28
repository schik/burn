include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = CreateIso
BUNDLE_EXTENSION = .burntool

CreateIso_RESOURCE_FILES = iconCreateIso.tiff

CreateIso_OBJC_FILES = \
	CreateIsoController.m \
	CreateIsoParametersView.m

CreateIso_HEADERS = \
	CreateIsoController.h \
	CreateIsoParametersView.h

CreateIso_PRINCIPAL_CLASS = \
	CreateIsoController

ADDITIONAL_OBJCFLAGS = -Wall

LIBISOFS_CFLAGS = `pkg-config --cflags-only-I libisofs-1`
ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/ $(LIBISOFS_CFLAGS)
BUNDLE_LIBS += `pkg-config --libs libisofs-1`

CreateIso_LANGUAGES=English German French
CreateIso_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Parameters.gorm

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
