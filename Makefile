TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LilLiftBoard
LilLiftBoard_FILES = Sources/Tweak.xm Sources/Prefs.m Sources/DockBar.m Sources/Actions.m Shared/LLBActionCatalog.m Shared/LLBDockStore.m
LilLiftBoard_CFLAGS = -fobjc-arc -ISources -IShared
LilLiftBoard_FRAMEWORKS = UIKit CoreGraphics
LilLiftBoard_USE_MODULES = 0

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += lilliftboardprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
