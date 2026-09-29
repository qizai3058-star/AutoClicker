TARGET := iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoClicker

AutoClicker_FILES = Tweak.x
AutoClicker_CFLAGS = -fobjc-arc
AutoClicker_FRAMEWORKS = UIKit CoreGraphics
AutoClicker_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS)/makefiles/tweak.mk
