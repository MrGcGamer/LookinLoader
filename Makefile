ARCHS  = arm64 arm64e
TARGET = iphone:clang:13.0:13.0
ADDITIONAL_OBJCFLAGS = -fobjc-arc
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LookinLoader
LookinLoader_FILES = Tweak.xm
LookinLoader_FRAMEWORKS = CoreSymbolication
LookinLoader_CFLAGS = -fobjc-arc -Wdeprecated-declarations -Wno-deprecated-declarations
LookinLoader_LDFLAGS += -FFrameworks/

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"
