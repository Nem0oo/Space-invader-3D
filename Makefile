TARGET = iphone:clang:latest:15.5
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpaceInvaders3D
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = SpaceInvaders3D
SpaceInvaders3D_FILES = AppDelegate.swift GameViewController.swift GameScene.swift PlayerShipController.swift CameraRig.swift AlienFormation.swift ProjectileManager.swift HUDOverlay.swift GameState.swift LevelData.swift StereoView.swift
SpaceInvaders3D_FRAMEWORKS = UIKit SceneKit QuartzCore
SpaceInvaders3D_RESOURCE_DIRS = Resources
include $(THEOS_MAKE_PATH)/application.mk
