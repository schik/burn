include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = AudioConverter
BUNDLE_EXTENSION = .burntool

AudioConverter_RESOURCE_FILES = iconAudioConverter.tiff

AudioConverter_OBJC_FILES = \
	AudioConverterController.m \
	AudioConverterSettingsView.m

AudioConverter_HEADERS = \
	AudioConverterController.h \
	AudioConverterSettingsView.h

AudioConverter_PRINCIPAL_CLASS = \
	AudioConverterController

ADDITIONAL_OBJCFLAGS = -Wall

ADDITIONAL_INCLUDE_DIRS += -I../.. -I../../Burn/

AudioConverter_LANGUAGES=English German French
AudioConverter_LOCALIZED_RESOURCE_FILES = \
	Localizable.strings \
	Settings.gorm

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
