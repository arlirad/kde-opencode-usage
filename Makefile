PACKAGE_ID := org.opencode.usage
PACKAGE_TYPE := Plasma/Applet
QMLTESTRUNNER ?= /usr/lib/qt6/bin/qmltestrunner

.PHONY: all verify test-ui install upgrade uninstall

all: verify

verify:
	python3 tests/verify_project.py

test-ui:
	QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde $(QMLTESTRUNNER) -input tests/tst_compact_activation.qml

install: verify
	kpackagetool6 --type $(PACKAGE_TYPE) --install .

upgrade: verify
	kpackagetool6 --type $(PACKAGE_TYPE) --upgrade .

uninstall:
	kpackagetool6 --type $(PACKAGE_TYPE) --remove $(PACKAGE_ID)
