#!/usr/bin/env bash
set -euo pipefail

# everything-opencode グローバルインストールスクリプト
# すべてのプロジェクトで使用できるようにOpencodeのグローバル設定ディレクトリに配置します

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_GLOBAL_DIR="${HOME}/.config/opencode"

echo "=========================================="
echo "everything-opencode グローバルインストール"
echo "=========================================="
echo ""

# グローバル設定ディレクトリを作成
echo "📁 グローバル設定ディレクトリを作成: ${OPENCODE_GLOBAL_DIR}"
mkdir -p "${OPENCODE_GLOBAL_DIR}"/{agents,commands,skills,plugins,themes}

# バックアップを作成（既存の設定がある場合）
if [ -f "${OPENCODE_GLOBAL_DIR}/opencode.json" ]; then
    BACKUP_FILE="${OPENCODE_GLOBAL_DIR}/opencode.json.backup.$(date +%Y%m%d_%H%M%S)"
    echo "⚠️  既存の設定をバックアップ: ${BACKUP_FILE}"
    cp "${OPENCODE_GLOBAL_DIR}/opencode.json" "${BACKUP_FILE}"
fi

# エージェントをコピー
echo "🤖 エージェントをコピー中..."
cp -r "${SCRIPT_DIR}/.opencode/agents/"* "${OPENCODE_GLOBAL_DIR}/agents/"
echo "   ✅ $(ls -1 "${SCRIPT_DIR}/.opencode/agents/" | wc -l) 個のエージェントをコピーしました"

# コマンドをコピー
echo "⚡ コマンドをコピー中..."
cp -r "${SCRIPT_DIR}/.opencode/commands/"* "${OPENCODE_GLOBAL_DIR}/commands/"
echo "   ✅ $(ls -1 "${SCRIPT_DIR}/.opencode/commands/" | wc -l) 個のコマンドをコピーしました"

# スキルをコピー
echo "🎯 スキルをコピー中..."
cp -r "${SCRIPT_DIR}/.opencode/skills/"* "${OPENCODE_GLOBAL_DIR}/skills/"
echo "   ✅ $(ls -1 "${SCRIPT_DIR}/.opencode/skills/" | wc -l) 個のスキルをコピーしました"

# opencode.jsonをコピー（グローバル用に調整済み）
echo "⚙️  グローバル設定ファイルをコピー中..."
cp "${SCRIPT_DIR}/opencode.json" "${OPENCODE_GLOBAL_DIR}/opencode.json"
echo "   ✅ opencode.json をコピーしました"

# AGENTS.mdをコピー
echo "📄 AGENTS.mdをコピー中..."
cp "${SCRIPT_DIR}/AGENTS.md" "${OPENCODE_GLOBAL_DIR}/AGENTS.md"
echo "   ✅ AGENTS.md をコピーしました"

# toolsディレクトリをコピー（アリーナシステム用）
echo "🛠️  ツールをコピー中..."
mkdir -p "${OPENCODE_GLOBAL_DIR}/tools"
cp -r "${SCRIPT_DIR}/tools/"* "${OPENCODE_GLOBAL_DIR}/tools/"
echo "   ✅ tools/ をコピーしました"

# scriptsディレクトリをコピー（バッチ起動用）
echo "📜 スクリプトをコピー中..."
mkdir -p "${OPENCODE_GLOBAL_DIR}/scripts"
cp -r "${SCRIPT_DIR}/scripts/"* "${OPENCODE_GLOBAL_DIR}/scripts/"
chmod +x "${OPENCODE_GLOBAL_DIR}/scripts/"*.sh
echo "   ✅ scripts/ をコピーしました"

# .envファイルの案内
echo ""
echo "=========================================="
echo "✅ インストール完了！"
echo "=========================================="
echo ""
echo "📍 インストール先: ${OPENCODE_GLOBAL_DIR}"
echo ""
echo "次のステップ:"
echo "1. 環境変数を設定してください:"
echo "   cp ${SCRIPT_DIR}/.env.example ~/.config/opencode/.env"
echo "   vi ~/.config/opencode/.env  # APIキーを設定"
echo ""
echo "2. 環境変数を読み込むために、以下を ~/.bashrc または ~/.zshrc に追加:"
echo "   export \$(grep -v '^#' ~/.config/opencode/.env | xargs)"
echo ""
echo "3. Opencodeを起動:"
echo "   opencode"
echo ""
echo "4. 利用可能なエージェント:"
echo "   - planner, code-reviewer, security-reviewer, architect"
echo "   - tdd-guide, build-error-resolver, e2e-runner"
echo "   - refactor-cleaner, doc-updater"
echo "   - central-planner (Arena), comp-a/b/c, qa-gate, integrator"
echo ""
echo "5. 利用可能なコマンド:"
echo "   /plan, /code-review, /security-audit, /architect"
echo "   /tdd, /build-fix, /e2e, /refactor, /doc-sync"
echo "   /arena (Arena Competition System)"
echo ""
echo "詳細はREADME.mdをご覧ください。"
echo ""
