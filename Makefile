target := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard Alipay

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AutoClicker

AutoClicker_FILES = Tweak.x
AutoClicker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

# 引入设置面板子项目
SUBPROJECTS += autoclickerprefs

include $(THEOS_MAKE_PATH)/aggregate.mk
