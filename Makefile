target := iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoClicker

AutoClicker_FILES = Tweak.x
AutoClicker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
