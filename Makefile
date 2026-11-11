TARGET := iphone:clang:14.4:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HadiTalabatFix

HadiTalabatFix_FILES = Tweak.x
HadiTalabatFix_FRAMEWORKS = UIKit CoreLocation MapKit WebKit Security
HadiTalabatFix_CFLAGS = -fobjc-arc -w
HadiTalabatFix_LDFLAGS = -install_name @rpath/libR6X9.dylib

include $(THEOS_MAKE_PATH)/tweak.mk
