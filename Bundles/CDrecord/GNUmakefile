include $(GNUSTEP_MAKEFILES)/common.make

ifeq ($(wodim),yes)
BUNDLE_NAME = Wodim
else
BUNDLE_NAME = CDrecord
endif

BUNDLE_EXTENSION = .burntool

$(BUNDLE_NAME)_RESOURCE_FILES = iconCDrecord.tiff

$(BUNDLE_NAME)_OBJC_FILES = \
	CDrecordController.m \
	CDrecordController+Private.m \
	CDrecordSettingsView.m \
	CDrecordParametersView.m

$(BUNDLE_NAME)_HEADERS = \
	CDrecordController.h \
	CDrecordSettingsView.h \
	CDrecordParametersView.h

$(BUNDLE_NAME)_PRINCIPAL_CLASS = \
	CDrecordController

ADDITIONAL_OBJCFLAGS = -Wall

ifeq ($(wodim),yes)
ADDITIONAL_OBJCFLAGS += -DWODIM
endif

ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/

$(BUNDLE_NAME)_LANGUAGES=English German French
$(BUNDLE_NAME)_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Settings.gorm \
	Parameters.gorm

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
