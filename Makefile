TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoClicker

AutoClicker_FILES = Tweak.mm
AutoClicker_FRAMEWORKS = UIKit Foundation CoreGraphics IOKit
AutoClicker_ENTITLEMENTS = autoclicker.entitlements

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
