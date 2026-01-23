#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# everything-opencode グローバル設定 簡単更新スクリプト
# =============================================================================
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/samurai2891/everything-opencode/main/update-global.sh | bash
#   または
#   bash update-global.sh
# =============================================================================

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  everything-opencode グローバル設定更新"
echo "=============================================="
echo ""

# 1. 一時ディレクトリに移動
cd /tmp

# 2. 既存のクローンを削除
log_info "既存のクローンを削除中..."
rm -rf everything-opencode

# 3. GitHubリポジトリをクローン
log_info "GitHubリポジトリをクローン中..."
if command -v gh &> /dev/null; then
    gh repo clone samurai2891/everything-opencode
else
    git clone https://github.com/samurai2891/everything-opencode.git
fi
log_success "クローン完了"

# 4. install-global.shを実行
log_info "グローバル設定をインストール中..."
cd everything-opencode
bash install-global.sh

echo ""
echo "=============================================="
echo -e "${GREEN}✅ 更新完了！${NC}"
echo "=============================================="
echo ""
echo "次のステップ:"
echo "  1. Opencodeを起動: opencode"
echo "  2. /arenaコマンドを試す: /arena 要件テキスト"
echo ""
echo "詳細: https://github.com/samurai2891/everything-opencode"
echo ""
