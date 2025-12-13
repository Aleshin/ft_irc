#!/bin/bash

# Быстрый старт для Phase 1 разработки

echo "🚀 FT_IRC Phase 1 - Quick Start"
echo

# Проверка ветки
current_branch=$(git branch --show-current)
if [ "$current_branch" != "phase1" ]; then
    echo "⚠️  Warning: You are on branch '$current_branch'"
    echo "   Switch to phase1 with: git checkout phase1"
    echo
fi

# Показать текущий статус
echo "📊 Current Status:"
echo

cd tests
make phase1

echo
echo "📋 Next Steps:"
echo
echo "1. Read the plan:"
echo "   📄 docs/DEVELOPMENT_PLAN.md"
echo
echo "2. Read testing guide:"
echo "   📄 docs/TESTING_GUIDE.md"
echo
echo "3. Start implementing Phase 1 tasks:"
echo "   - Fix POLLOUT dynamic handling (CRITICAL)"
echo "   - Fix iteration over _pollfds (CRITICAL)"
echo "   - Implement command extraction (CRITICAL)"
echo
echo "4. After each change, run:"
echo "   cd tests && make phase1"
echo
echo "5. When Phase 1 is complete:"
echo "   git checkout main"
echo "   git merge phase1"
echo
echo "Good luck! 🎯"
