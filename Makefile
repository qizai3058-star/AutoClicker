TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Alipay

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoClicker

AutoClicker_FILES = Tweak.x
AutoClicker_EXTRA_FRAMEWORKS = IOKit

include $(THEOS_MAKE_PATH)/tweak.mk
