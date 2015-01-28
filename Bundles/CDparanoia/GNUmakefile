include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = CDparanoia
BUNDLE_EXTENSION = .burntool

CDparanoia_RESOURCE_FILES = iconCDparanoia.tiff

CDparanoia_OBJC_FILES = \
	CDparanoiaController.m \
	CDparanoiaSettingsView.m \
	CDparanoiaParametersView.m

CDparanoia_HEADERS = \
	CDparanoiaController.h \
	CDparanoiaSettingsView.h \
	CDparanoiaParametersView.h

CDparanoia_PRINCIPAL_CLASS = \
	CDparanoiaController

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/

CDparanoia_LANGUAGES=English German French
CDparanoia_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Settings.gorm \
	Parameters.gorm

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
