ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = Glovo

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LocationHook
LocationHook_FILES = Tweak.x
LocationHook_FRAMEWORKS = UIKit CoreLocation QuartzCore WebKit
LocationHook_LIBRARIES = c++
LocationHook_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function -Wno-nullability-completeness
LocationHook_LDFLAGS = -Wl,-segalign,4000

include $(THEOS_MAKE_PATH)/tweak.mk
