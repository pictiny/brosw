APP = Brosw
CONFIG ?= release
BUILD_DIR = .build/$(CONFIG)
BUNDLE = build/$(APP).app

.PHONY: build dev install uninstall run icon clean

# 製品ビルド(テスト用メニューなし)
build:
	swift build -c $(CONFIG)
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/
	cp Resources/MenuBarIcon.png $(BUNDLE)/Contents/Resources/
	cp -R Resources/*.lproj $(BUNDLE)/Contents/Resources/
	printf 'APPL????' > $(BUNDLE)/Contents/PkgInfo
	cp $(BUILD_DIR)/$(APP) $(BUNDLE)/Contents/MacOS/$(APP)
	codesign --force --sign - $(BUNDLE)

# 開発ビルド(DEBUG 定義。「テスト: ピッカーを表示」メニューあり)
dev:
	$(MAKE) build CONFIG=debug

install: build
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/$(APP).app
	open /Applications/$(APP).app

uninstall:
	-pkill -x $(APP)
	rm -rf /Applications/$(APP).app

run: dev
	open $(BUNDLE)

# Resources/AppIcon.png から Resources/AppIcon.icns を再生成
icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build build
