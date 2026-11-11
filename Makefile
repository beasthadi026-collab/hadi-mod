TARGET := iphone:clang:latest:14.0
ARCHS := arm64

MODULE_NAME := HadiTalabatFix
$(MODULE_NAME)_FILES := Tweak.x
$(MODULE_NAME)_FRAMEWORKS := UIKit CoreLocation MapKit WebKit Security
$(MODULE_NAME)_LDFLAGS := -install_name @rpath/libR6X9.dylib

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

