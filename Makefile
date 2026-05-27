# HeartBeatStream — common commands
# Run `make help` to list available targets.

# --- Config ---------------------------------------------------------------
IOS_SCHEME    := HeartBeatStream
IOS_PROJECT   := ios/HeartBeatStream/HeartBeatStream/HeartBeatStream.xcodeproj
WEB_DIR       := web
WEB_PORT      ?= 8000

.DEFAULT_GOAL := help

# --- Help -----------------------------------------------------------------
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# --- Web client -----------------------------------------------------------
.PHONY: web
web: ## Serve the web client locally (nebula at /)
	@echo "Nebula: http://localhost:$(WEB_PORT)/index.html"
	python3 -m http.server --directory $(WEB_DIR) $(WEB_PORT)

.PHONY: web-open
web-open: ## Open the nebula page in the default browser
	open http://localhost:$(WEB_PORT)/index.html

# --- iOS app --------------------------------------------------------------
.PHONY: ios-open
ios-open: ## Open the iOS app in Xcode
	xed ios/HeartBeatStream

.PHONY: ios-build
ios-build: ## Build the iOS app (generic iOS device)
	xcodebuild -scheme $(IOS_SCHEME) -destination 'generic/platform=iOS' build

.PHONY: ios-sim
ios-sim: ## Build, install & launch on the iOS Simulator (DEVICE="iPhone 16")
	./scripts/run-simulator.sh $(DEVICE)

.PHONY: ios-clean
ios-clean: ## Clean the iOS build
	xcodebuild -scheme $(IOS_SCHEME) clean

# --- Tests ----------------------------------------------------------------
.PHONY: test
test: ## Run the web app unit tests (Node built-in test runner)
	node --test "test/**/*.test.js"

# --- Backend / deploy -----------------------------------------------------
.PHONY: install
install: ## Install Node dependencies (Vercel CLI)
	npm install

.PHONY: dev
dev: ## Run the full stack locally with Vercel (serverless + web)
	npx vercel dev

.PHONY: deploy
deploy: ## Deploy to Vercel production
	npx vercel --prod

# --- Misc -----------------------------------------------------------------
.PHONY: config
config: ## Check the live /api/config endpoint (set BASE_URL=...)
	curl -s $(BASE_URL)/api/config | python3 -m json.tool
