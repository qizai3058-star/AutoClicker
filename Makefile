target := iphone:clang:latest:14.0
ARCHS = arm64
LIBRARY_NAME = AutoClicker

AutoClicker_FILES = Tweak.mm
AutoClicker_CFLAGS = -fobjc-arc
AutoClicker_FRAMEWORKS = UIKit WebKit

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/library.mk
