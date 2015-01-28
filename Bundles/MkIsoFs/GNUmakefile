include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = MkIsoFs
BUNDLE_EXTENSION = .burntool

MkIsoFs_RESOURCE_FILES = iconMkIsoFs.tiff

MkIsoFs_OBJC_FILES = \
	MkIsoFsController.m \
	MkIsoFsController+Private.m \
	MkIsoFsSettingsView.m \
	MkIsoFsParametersView.m

MkIsoFs_HEADERS = \
	MkIsoFsController.h \
	MkIsoFsSettingsView.h \
	MkIsoFsParametersView.h

MkIsoFs_PRINCIPAL_CLASS = \
	MkIsoFsController

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/

MkIsoFs_LANGUAGES=English German French
MkIsoFs_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Settings.gorm \
	Parameters.gorm

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
