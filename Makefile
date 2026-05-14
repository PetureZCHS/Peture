IOS_DIR := ios

.PHONY: tf tf-help

tf:
	cd $(IOS_DIR) && bundle exec fastlane beta \
		$(if $(BUILD_NAME),build_name:$(BUILD_NAME),) \
		$(if $(BUILD_NUMBER),build_number:$(BUILD_NUMBER),) \
		$(if $(NOTE),changelog:"$(NOTE)",)

tf-help:
	@echo "Usage:"
	@echo "  make tf"
	@echo "  make tf BUILD_NAME=1.0.1 BUILD_NUMBER=12 NOTE='修复已知问题'"
