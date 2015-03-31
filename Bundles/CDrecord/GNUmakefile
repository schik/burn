include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = CDrecord
BUNDLE_EXTENSION = .burntool

CDrecord_RESOURCE_FILES = iconCDrecord.tiff

CDrecord_OBJC_FILES = \
	CDrecordController.m \
	CDrecordController+Private.m \
	CDrecordSettingsView.m \
	CDrecordParametersView.m

CDrecord_HEADERS = \
	CDrecordController.h \
	CDrecordSettingsView.h \
	CDrecordParametersView.h

CDrecord_PRINCIPAL_CLASS = \
	CDrecordController

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/

CDrecord_LANGUAGES=English German French
CDrecord_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Settings.gorm \
	Parameters.gorm

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
