.PHONY: help install build test deploy setup-env start-backend start-anvil stop-all test-all clean

GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m 

ANVIL_PORT := 8545
BACKEND_PORT := 3000
ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL := http://127.0.0.1:$(ANVIL_PORT)
CONTRACT_DIR := crowdy
BACKEND_DIR := backend

help:
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

install:
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@echo "$(YELLOW)Installing Foundry dependencies (forge-std, openzeppelin-contracts)...$(NC)"
	@cd $(CONTRACT_DIR) && \
		if [ ! -d ".git" ]; then \
			echo "$(YELLOW)  Initializing git repository for dependency management...$(NC)"; \
			git init > /dev/null 2>&1; \
			git config user.email "install@local" > /dev/null 2>&1; \
			git config user.name "Local Install" > /dev/null 2>&1; \
		fi; \
		if [ ! -d "lib/forge-std" ]; then \
			echo "$(GREEN)  Installing forge-std...$(NC)"; \
			forge install foundry-rs/forge-std > /dev/null 2>&1 || true; \
		fi; \
		if [ ! -d "lib/openzeppelin-contracts" ]; then \
			echo "$(GREEN)  Installing openzeppelin-contracts...$(NC)"; \
			forge install OpenZeppelin/openzeppelin-contracts > /dev/null 2>&1 || true; \
		fi; \
		echo "$(GREEN)  Foundry dependencies installed$(NC)"
	@echo "$(YELLOW)Installing Node.js dependencies...$(NC)"
	@cd $(BACKEND_DIR) && npm install
	@echo "$(GREEN) Dependencies installed$(NC)"

build:
	@echo "$(GREEN)Building smart contract...$(NC)"
	@cd $(CONTRACT_DIR) && forge build
	@echo "$(GREEN) Contract built successfully$(NC)"

test: 
	@echo "$(GREEN)Running smart contract tests...$(NC)"
	@cd $(CONTRACT_DIR) && forge test
	@echo "$(GREEN) Tests completed$(NC)"

start-anvil: 
	@echo "$(GREEN)Starting Anvil...$(NC)"
	@if pgrep -f "anvil" > /dev/null; then \
		echo "$(YELLOW) Anvil is already running$(NC)"; \
	else \
		anvil > /tmp/anvil.log 2>&1 & \
		echo "$$!" > /tmp/anvil.pid; \
		sleep 2; \
		if curl -s $(RPC_URL) > /dev/null 2>&1; then \
			echo "$(GREEN) Anvil started on port $(ANVIL_PORT)$(NC)"; \
		else \
			echo "$(RED) Failed to start Anvil$(NC)"; \
			exit 1; \
		fi \
	fi

stop-anvil: 
	@echo "$(GREEN)Stopping Anvil...$(NC)"
	@pkill -f "anvil" || true
	@rm -f /tmp/anvil.pid
	@echo "$(GREEN) Anvil stopped$(NC)"

deploy: start-anvil
	@echo "$(GREEN)Deploying contract...$(NC)"
	@cd $(CONTRACT_DIR) && forge script script/Crowdy.s.sol:CrowdfundCampaignScript \
		--rpc-url $(RPC_URL) \
		--broadcast \
		--private-key $(ANVIL_KEY) \
		-vv > /tmp/deploy.log 2>&1 || (cat /tmp/deploy.log && exit 1)
	@cd $(CONTRACT_DIR) && python3 -c "import json, sys; \
		data = json.load(open('broadcast/Crowdy.s.sol/31337/run-latest.json')); \
		addr = data['transactions'][0]['contractAddress']; \
		print(addr)" > /tmp/contract_address.txt
	@echo "$(GREEN)Contract deployed$(NC)"
	@echo "$(GREEN)Contract address: $$(cat /tmp/contract_address.txt)$(NC)"

setup-env: deploy 
	@echo "$(GREEN)Setting up backend .env file...$(NC)"
	@CONTRACT_ADDR=$$(cat /tmp/contract_address.txt); \
	echo "RPC_URL=$(RPC_URL)" > $(BACKEND_DIR)/.env; \
	echo "CONTRACT_ADDRESS=$$CONTRACT_ADDR" >> $(BACKEND_DIR)/.env; \
	echo "PRIVATE_KEY=$(ANVIL_KEY)" >> $(BACKEND_DIR)/.env; \
	echo "PORT=$(BACKEND_PORT)" >> $(BACKEND_DIR)/.env; \
	echo "$(GREEN) .env file created:$(NC)"; \
	cat $(BACKEND_DIR)/.env

start-backend: setup-env 
	@echo "$(GREEN)Starting backend server...$(NC)"
	@if pgrep -f "node.*index.js" > /dev/null; then \
		echo "$(YELLOW) Backend is already running$(NC)"; \
	else \
		cd $(BACKEND_DIR) && npm start > /tmp/backend.log 2>&1 & \
		echo "$$!" > /tmp/backend.pid; \
		sleep 3; \
		if curl -s http://localhost:$(BACKEND_PORT)/health > /dev/null 2>&1; then \
			echo "$(GREEN) Backend started on port $(BACKEND_PORT)$(NC)"; \
			curl -s http://localhost:$(BACKEND_PORT)/health | python3 -m json.tool 2>/dev/null || true; \
		else \
			echo "$(RED) Failed to start backend$(NC)"; \
			echo "$(YELLOW)Check logs: tail -f /tmp/backend.log$(NC)"; \
			exit 1; \
		fi \
	fi

stop-backend: 
	@echo "$(GREEN)Stopping backend...$(NC)"
	@pkill -f "node.*index.js" || true
	@rm -f /tmp/backend.pid
	@echo "$(GREEN) Backend stopped$(NC)"

stop-all: stop-backend stop-anvil 
	@echo "$(GREEN) All services stopped$(NC)"

test-backend: 
	@echo "$(GREEN)Testing backend API...$(NC)"
	@if ! curl -s http://localhost:$(BACKEND_PORT)/health > /dev/null 2>&1; then \
		echo "$(RED) Backend is not running. Run 'make start-backend' first$(NC)"; \
		exit 1; \
	fi
	@cd $(BACKEND_DIR) && ./test-api.sh || echo "$(YELLOW)  Test script not found, running manual tests...$(NC)"
	@echo "$(GREEN) Backend tests completed$(NC)"

test-contract: 
	@echo "$(GREEN)Testing smart contract...$(NC)"
	@cd $(CONTRACT_DIR) && forge test --summary
	@echo "$(GREEN) Contract tests completed$(NC)"

test-all: test-contract test-backend
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN) ALL TESTS COMPLETED$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"

run: start-backend 
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN) PROJECT IS RUNNING!$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(YELLOW)Services:$(NC)"
	@echo "  • Anvil:      $(RPC_URL)"
	@echo "  • Backend:    http://localhost:$(BACKEND_PORT)"
	@echo "  • Contract:   $$(cat /tmp/contract_address.txt 2>/dev/null || echo 'Not deployed')"
	@echo ""
	@echo "$(YELLOW)Useful commands:$(NC)"
	@echo "  • Test API:   make test-backend"
	@echo "  • Test Contract: make test-contract"
	@echo "  • Stop all:   make stop-all"
	@echo "  • View logs:  tail -f /tmp/backend.log"
	@echo ""

clean: stop-all 
	@echo "$(GREEN)Cleaning up...$(NC)"
	@rm -f /tmp/contract_address.txt
	@rm -f /tmp/deploy.log
	@rm -f /tmp/anvil.log
	@rm -f /tmp/backend.log
	@rm -f /tmp/*.pid
	@echo "$(GREEN) Cleanup complete$(NC)"

status:
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN) SERVICE STATUS$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@if pgrep -f "anvil" > /dev/null; then \
		echo "$(GREEN) Anvil:$(NC) Running on $(RPC_URL)"; \
	else \
		echo "$(RED) Anvil:$(NC) Not running"; \
	fi
	@if pgrep -f "node.*index.js" > /dev/null; then \
		echo "$(GREEN) Backend:$(NC) Running on http://localhost:$(BACKEND_PORT)"; \
		if [ -f /tmp/contract_address.txt ]; then \
			echo "$(GREEN) Contract:$(NC) $$(cat /tmp/contract_address.txt)"; \
		else \
			echo "$(YELLOW) Contract:$(NC) Not deployed"; \
		fi \
	else \
		echo "$(RED) Backend:$(NC) Not running"; \
	fi
	@echo ""

