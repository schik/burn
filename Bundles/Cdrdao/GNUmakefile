include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = Cdrdao
BUNDLE_EXTENSION = .burntool

Cdrdao_RESOURCE_FILES = iconCdrdao.tiff

Cdrdao_OBJC_FILES = \
	CdrdaoSettingsView.m \
	CdrdaoController.m \
	CdrdaoController+Private.m

Cdrdao_HEADERS = \
	CdrdaoSettingsView.h \
	CdrdaoController.h

Cdrdao_PRINCIPAL_CLASS = \
	CdrdaoController

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/

Cdrdao_LANGUAGES=English German French
Cdrdao_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Settings.gorm

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
