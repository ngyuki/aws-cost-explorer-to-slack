AWS		:= aws
LAMBDA		:= billing-daily-notification
SRC_FILES	:= index.js
BUILD_DIR	:= .build
BUILD_ENV_DIR	:= $(BUILD_DIR)/$(APP_ENV)

.PHONY: all
all: invoke

.PHONY: build
build: $(BUILD_DIR)/package.zip

$(BUILD_DIR)/node_modules.zip: package.json package-lock.json
	mkdir -p $(BUILD_DIR)
	cp package.json package-lock.json $(BUILD_DIR)
	cd $(BUILD_DIR) && npm ci --prod
	rm -f $(BUILD_DIR)/node_modules.zip
	cd $(BUILD_DIR) && zip -r node_modules.zip node_modules

$(BUILD_DIR)/package.zip: $(BUILD_DIR)/node_modules.zip $(SRC_FILES)
	mkdir -p $(BUILD_DIR)
	cp $(BUILD_DIR)/node_modules.zip $(BUILD_DIR)/package~.zip
	zip -r $(BUILD_DIR)/package~.zip $(SRC_FILES)
	mv $(BUILD_DIR)/package~.zip $(BUILD_DIR)/package.zip

.PHONY: deploy
deploy: $(BUILD_ENV_DIR)/deploy.json
$(BUILD_ENV_DIR)/deploy.json: $(BUILD_DIR)/package.zip
	mkdir -p $(@D)
	$(AWS) lambda update-function-code --function-name $(LAMBDA) --zip-file fileb://$< > $@~
	mv $@~ $@

.PHONY: invoke
invoke: deploy
	mkdir -p $(BUILD_DIR)
	$(AWS) lambda invoke --function-name $(LAMBDA) --invocation-type RequestResponse \
		--log-type Tail $(BUILD_DIR)/response.json | jq '.LogResult | @base64d' -r

.PHONY: clean
clean:
	rm -fr $(BUILD_DIR)
