target := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoClicker

AutoClicker_FILES = Tweak.x
AutoClicker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
