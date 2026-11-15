TARGET := iphone:clang:16.5:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LilLiftBoardPrefs
LilLiftBoardPrefs_FILES = LLBPrefsRootListController.m
LilLiftBoardPrefs_CFLAGS = -fobjc-arc
LilLiftBoardPrefs_FRAMEWORKS = UIKit
LilLiftBoardPrefs_PRIVATE_FRAMEWORKS = Preferences
LilLiftBoardPrefs_INSTALL_PATH = /Library/PreferenceBundles
LilLiftBoardPrefs_USE_MODULES = 0

include $(THEOS_MAKE_PATH)/bundle.mk
