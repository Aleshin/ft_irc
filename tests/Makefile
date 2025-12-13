# Makefile для тестирования FT_IRC

.PHONY: all phase1 phase2 phase3 phase4 phase5 unit integration stress clean help

# Цвета для вывода
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Директория с основным проектом
PROJECT_DIR = ..

all: help

help:
	@echo "$(BLUE)FT_IRC Testing Framework$(NC)"
	@echo
	@echo "Available targets:"
	@echo "  $(GREEN)make phase1$(NC)       - Run Phase 1 tests (critical fixes)"
	@echo "  $(GREEN)make phase2$(NC)       - Run Phase 2 tests (command parsing)"
	@echo "  $(GREEN)make phase3$(NC)       - Run Phase 3 tests (registration)"
	@echo "  $(GREEN)make phase4$(NC)       - Run Phase 4 tests (channels)"
	@echo "  $(GREEN)make phase5$(NC)       - Run Phase 5 tests (operator commands)"
	@echo
	@echo "  $(YELLOW)make unit$(NC)         - Run unit tests"
	@echo "  $(YELLOW)make integration$(NC)  - Run integration tests"
	@echo "  $(YELLOW)make stress$(NC)       - Run stress tests"
	@echo "  $(YELLOW)make valgrind$(NC)     - Run valgrind memory check"
	@echo
	@echo "  $(RED)make clean$(NC)        - Clean test artifacts"
	@echo

# Проверка компиляции проекта
compile:
	@echo "$(BLUE)Compiling project...$(NC)"
	@$(MAKE) -C $(PROJECT_DIR) > /dev/null 2>&1 || \
		(echo "$(RED)✗ Compilation failed$(NC)" && exit 1)
	@echo "$(GREEN)✓ Compilation successful$(NC)"
	@echo

# Phase 1: Критические исправления
phase1: compile
	@echo "$(BLUE)Running Phase 1 tests...$(NC)"
	@chmod +x phase_tests/phase1_tests.sh
	@bash phase_tests/phase1_tests.sh

# Phase 2: Парсинг команд
phase2: compile
	@echo "$(BLUE)Running Phase 2 tests...$(NC)"
	@chmod +x phase_tests/phase2_tests.sh
	@bash phase_tests/phase2_tests.sh || echo "$(YELLOW)Phase 2 tests not yet implemented$(NC)"

# Phase 3: Регистрация
phase3: compile
	@echo "$(BLUE)Running Phase 3 tests...$(NC)"
	@chmod +x phase_tests/phase3_tests.sh
	@bash phase_tests/phase3_tests.sh || echo "$(YELLOW)Phase 3 tests not yet implemented$(NC)"

# Phase 4: Каналы
phase4: compile
	@echo "$(BLUE)Running Phase 4 tests...$(NC)"
	@chmod +x phase_tests/phase4_tests.sh
	@bash phase_tests/phase4_tests.sh || echo "$(YELLOW)Phase 4 tests not yet implemented$(NC)"

# Phase 5: Операторские команды
phase5: compile
	@echo "$(BLUE)Running Phase 5 tests...$(NC)"
	@chmod +x phase_tests/phase5_tests.sh
	@bash phase_tests/phase5_tests.sh || echo "$(YELLOW)Phase 5 tests not yet implemented$(NC)"

# Unit тесты
unit: compile
	@echo "$(BLUE)Running unit tests...$(NC)"
	@if [ -d unit ]; then \
		$(MAKE) -C unit 2>/dev/null || echo "$(YELLOW)Unit tests not yet implemented$(NC)"; \
	else \
		echo "$(YELLOW)Unit tests not yet implemented$(NC)"; \
	fi

# Integration тесты
integration: compile
	@echo "$(BLUE)Running integration tests...$(NC)"
	@if [ -f integration/test_registration.sh ]; then \
		chmod +x integration/*.sh; \
		bash integration/test_registration.sh; \
	else \
		echo "$(YELLOW)Integration tests not yet implemented$(NC)"; \
	fi

# Stress тесты
stress: compile
	@echo "$(BLUE)Running stress tests...$(NC)"
	@if [ -f stress/test_100_clients.sh ]; then \
		chmod +x stress/*.sh; \
		bash stress/test_100_clients.sh; \
	else \
		echo "$(YELLOW)Stress tests not yet implemented$(NC)"; \
	fi

# Valgrind проверка
valgrind: compile
	@echo "$(BLUE)Running valgrind check...$(NC)"
	@if command -v valgrind >/dev/null 2>&1; then \
		valgrind --leak-check=full --error-exitcode=1 \
			--log-file=/tmp/valgrind_full.log \
			$(PROJECT_DIR)/ircserv 6667 test & \
		sleep 3; \
		kill $$! 2>/dev/null || true; \
		wait $$! 2>/dev/null || true; \
		if grep -q "ERROR SUMMARY: 0 errors" /tmp/valgrind_full.log; then \
			echo "$(GREEN)✓ Valgrind check passed$(NC)"; \
		else \
			echo "$(RED)✗ Valgrind check failed$(NC)"; \
			cat /tmp/valgrind_full.log; \
			exit 1; \
		fi; \
	else \
		echo "$(YELLOW)⊘ valgrind not installed$(NC)"; \
	fi

# Очистка
clean:
	@echo "$(BLUE)Cleaning test artifacts...$(NC)"
	@rm -f /tmp/irc_test_*
	@rm -f /tmp/irc_server_*.log
	@rm -f /tmp/valgrind*.log
	@rm -f /tmp/make.log
	@rm -f /tmp/test_*.log
	@if [ -d unit ]; then $(MAKE) -C unit clean 2>/dev/null || true; fi
	@echo "$(GREEN)✓ Cleaned$(NC)"

# Continuous testing (запуск всех доступных тестов)
continuous: compile
	@echo "$(BLUE)Running all available tests...$(NC)"
	@$(MAKE) phase1 || true
	@echo
	@$(MAKE) phase2 || true
	@echo
	@$(MAKE) phase3 || true
	@echo
	@$(MAKE) unit || true
	@echo
	@$(MAKE) integration || true

# Быстрая проверка (без стресс-тестов)
quick: compile phase1
	@echo "$(GREEN)Quick check complete$(NC)"
