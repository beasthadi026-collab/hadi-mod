ARCHS = arm64 arm64e
TARGET = iphone:clang:14.5:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LocationHook
LocationHook_FILES = Tweak.x
LocationHook_FRAMEWORKS = CoreLocation
LocationHook_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
