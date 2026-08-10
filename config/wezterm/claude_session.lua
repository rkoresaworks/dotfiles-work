local wezterm = require("wezterm")
local act = wezterm.action
local module = {}

-- アイコン定義
local ICONS = {
	workspace = wezterm.nerdfonts.md_view_dashboard,
	project = wezterm.nerdfonts.md_folder,
	claude = wezterm.nerdfonts.md_robot,
	separator = wezterm.nerdfonts.ple_right_half_circle_thin,
	status_running = "●",
	status_waiting = "◐",
	status_idle = "○",
}

-- プロジェクト名を取得（パスから）
local function get_project_name(path)
	if not path or path == "" then
		return "unknown"
	end
	path = path:gsub("/$", "")
	local project_name = path:match("([^/]+)$")
	return project_name or "unknown"
end

-- UTF-8文字列をサニタイズ（不正なバイトを除去）
local function sanitize_utf8(str)
	if not str or str == "" then
		return ""
	end

	local result = {}
	local i = 1
	while i <= #str do
		local success, _ = pcall(utf8.codepoint, str, i)
		if success then
			local next_i = utf8.offset(str, 2, i)
			if next_i then
				table.insert(result, str:sub(i, next_i - 1))
				i = next_i
			else
				table.insert(result, str:sub(i))
				break
			end
		else
			i = i + 1
		end
	end

	return table.concat(result)
end

-- ペインタイトルからClaudeのステータスを判定
local function get_claude_status(pane)
	local success, title = pcall(function()
		return pane:get_title()
	end)
	if not success or not title or title == "" then
		return "idle"
	end
	-- 点字スピナー (U+2800-U+28FF)
	if title:find("\xe2\xa0") then
		return "running"
	end
	-- ✳ (U+2733)
	if title:find("\xe2\x9c\xb3") then
		return "waiting"
	end
	return "idle"
end

-- ペインタイトルからセッション内容を取得
local function get_session_content(pane)
	local success, title = pcall(function()
		return pane:get_title()
	end)

	if not success or not title or title == "" then
		return ""
	end

	title = sanitize_utf8(title)
	if title == "" then
		return ""
	end

	-- 括弧内のテキストを削除（ヘルプテキストなど）
	title = title:gsub("%s*%([^)]+%)%s*", " ")
	title = title:gsub("^%s+", ""):gsub("%s+$", "")

	local success_width, width = pcall(wezterm.column_width, title)
	if success_width and width > 60 then
		local success_truncate, truncated = pcall(wezterm.truncate_right, title, 60)
		if success_truncate then
			return truncated
		end
	end

	return title
end

-- 現在実行中のClaude Codeセッションをスキャン
local function scan_active_claude_sessions()
	local sessions = {}

	for _, mux_window in ipairs(wezterm.mux.all_windows()) do
		local workspace = mux_window:get_workspace()

		for _, tab in ipairs(mux_window:tabs()) do
			local tab_title = tab:get_title()
			local tab_id = tab:tab_id()

			for _, pane_info in ipairs(tab:panes_with_info()) do
				local pane = pane_info.pane
				local process_name = pane:get_foreground_process_name()

				if process_name and process_name:find("claude") then
					local cwd_url = pane:get_current_working_dir()
					local cwd = cwd_url and cwd_url.file_path or ""
					local content = get_session_content(pane)

					table.insert(sessions, {
						pane = pane,
						workspace = workspace,
						tab_title = tab_title,
						cwd = cwd,
						content = content,
						status = get_claude_status(pane),
						pane_id = pane:pane_id(),
						mux_window = mux_window,
						tab = tab,
						tab_id = tab_id,
					})
				end
			end
		end
	end

	return sessions
end

-- JSON文字列のエスケープ
local function json_escape(str)
	if not str then
		return ""
	end
	str = tostring(str)
	str = str:gsub("\\", "\\\\")
	str = str:gsub('"', '\\"')
	str = str:gsub("\n", "\\n")
	str = str:gsub("\r", "\\r")
	str = str:gsub("\t", "\\t")
	return str
end

-- セッション情報をJSON Lines形式でファイルに出力
local function export_sessions_to_file(sessions, filepath)
	local lines = {}
	for _, session in ipairs(sessions) do
		local project_name = get_project_name(session.cwd)
		local json = string.format(
			'{"pane_id":"%s","workspace":"%s","project":"%s","cwd":"%s","content":"%s","tab_title":"%s","status":"%s"}',
			json_escape(tostring(session.pane_id)),
			json_escape(session.workspace or "default"),
			json_escape(project_name),
			json_escape(session.cwd or ""),
			json_escape(session.content or ""),
			json_escape(session.tab_title or ""),
			json_escape(session.status or "idle")
		)
		table.insert(lines, json)
	end

	local file = io.open(filepath, "w")
	if not file then
		wezterm.log_error("Failed to open file for writing: " .. filepath)
		return false
	end

	file:write(table.concat(lines, "\n") .. "\n")
	file:close()
	return true
end

-- セッション情報をfzf用にフォーマット（ANSI色付き）
local function format_session_for_fzf(session, is_current)
	local purple = "\x1b[38;5;141m"
	local blue = "\x1b[38;5;117m"
	local white = "\x1b[38;5;255m"
	local gray = "\x1b[38;5;240m"
	local dim = "\x1b[2m"
	local reset = "\x1b[0m"

	local status_styles = {
		running = { color = "\x1b[38;5;114m", icon = ICONS.status_running },
		waiting = { color = "\x1b[38;5;214m", icon = ICONS.status_waiting },
		idle = { color = "\x1b[38;5;240m", icon = ICONS.status_idle },
	}

	local workspace = session.workspace or "default"
	local project_name = get_project_name(session.cwd)
	local content = session.content or ""
	local pane_id = tostring(session.pane_id)
	local status = session.status or "idle"
	local style = status_styles[status] or status_styles.idle

	local status_prefix = string.format("%s%s%s ", style.color, style.icon, reset)
	local current_tag = is_current and (gray .. " (current)" .. reset) or ""

	if content ~= "" then
		return string.format(
			"%s%s%s %s%s %s%s%s %s%s %s%s %s%s%s %s%s%s%s|%s",
			status_prefix,
			purple,
			ICONS.workspace,
			workspace,
			reset,
			gray,
			ICONS.separator,
			reset,
			blue,
			ICONS.project,
			project_name,
			reset,
			gray,
			ICONS.separator,
			reset,
			white,
			content,
			reset,
			current_tag,
			pane_id
		)
	else
		return string.format(
			"%s%s%s %s%s %s%s%s %s%s %s%s%s|%s",
			status_prefix,
			purple,
			ICONS.workspace,
			workspace,
			reset,
			gray,
			ICONS.separator,
			reset,
			blue,
			ICONS.project,
			project_name,
			reset,
			current_tag,
			pane_id
		)
	end
end

-- 全セッションをフォーマットしてファイル出力（現在のセッションを末尾に配置）
local function export_formatted_sessions_to_file(sessions, filepath, current_pane_id)
	local other_lines = {}
	local current_lines = {}
	for _, session in ipairs(sessions) do
		local is_current = (current_pane_id and session.pane_id == current_pane_id)
		local line = format_session_for_fzf(session, is_current)
		if is_current then
			table.insert(current_lines, line)
		else
			table.insert(other_lines, line)
		end
	end
	-- 他のセッションを先に、現在のセッションを末尾に
	local lines = {}
	for _, l in ipairs(other_lines) do table.insert(lines, l) end
	for _, l in ipairs(current_lines) do table.insert(lines, l) end

	local file = io.open(filepath, "w")
	if not file then
		wezterm.log_error("Failed to open file for writing: " .. filepath)
		return false
	end

	file:write(table.concat(lines, "\n") .. "\n")
	file:close()
	return true
end

-- アクティベーションスクリプトを生成（shell 側で実行）
local function build_activate_script()
	local homebrew_prefix = os.getenv("HOMEBREW_PREFIX") or "/opt/homebrew"
	local wezterm_bin = homebrew_prefix .. "/bin/wezterm"
	local aerospace_bin = homebrew_prefix .. "/bin/aerospace"
	local jq_bin = "/usr/bin/jq"

	-- ウィンドウタイトルにプロジェクト名が含まれる前提で、
	-- AeroSpace のウィンドウ一覧からプロジェクト名で特定してフォーカス
	return string.format([[
#!/bin/bash
PANE_ID="$1"
CURRENT_PANE_ID="$2"
WEZTERM="%s"
AEROSPACE="%s"
JQ="%s"

# ターゲットペインと現在のペインの window_id + CWD を取得
WEZTERM_JSON=$("$WEZTERM" cli list --format json 2>/dev/null)
TARGET_WIN=$(echo "$WEZTERM_JSON" | "$JQ" -r ".[] | select(.pane_id == ${PANE_ID}) | .window_id")
CURRENT_WIN=$(echo "$WEZTERM_JSON" | "$JQ" -r ".[] | select(.pane_id == ${CURRENT_PANE_ID}) | .window_id")
TARGET_CWD=$(echo "$WEZTERM_JSON" | "$JQ" -r ".[] | select(.pane_id == ${PANE_ID}) | .cwd")
TARGET_PROJECT=$(echo "$TARGET_CWD" | sed 's|file://||' | sed 's|/$||' | awk -F/ '{print $NF}')

# mux レベルでペインをアクティブ化
"$WEZTERM" cli activate-pane --pane-id "$PANE_ID" 2>/dev/null

# AeroSpace が使えないか、同じウィンドウならここで終了
[ ! -x "$AEROSPACE" ] && exit 0
[ -z "$TARGET_WIN" ] || [ "$TARGET_WIN" = "$CURRENT_WIN" ] && exit 0

# プロジェクト名で AeroSpace ウィンドウを特定（ウィンドウタイトルに "— project" が含まれる）
if [ -n "$TARGET_PROJECT" ]; then
  TARGET_AERO=$("$AEROSPACE" list-windows --all 2>/dev/null | grep WezTerm | grep -- "$TARGET_PROJECT" | awk -F'|' '{gsub(/^ +| +$/, "", $1); print $1}' | head -1)
  if [ -n "$TARGET_AERO" ]; then
    "$AEROSPACE" focus --window-id "$TARGET_AERO" 2>/dev/null
    exit 0
  fi
fi

# フォールバック: プロジェクト名で見つからない場合は現在以外を試す
FOCUSED_AERO=$("$AEROSPACE" list-windows --focused 2>/dev/null | awk '{print $1}')
"$AEROSPACE" list-windows --all 2>/dev/null | grep WezTerm | awk -F'|' '{gsub(/^ +| +$/, "", $1); print $1}' | while read WID; do
  if [ "$WID" != "$FOCUSED_AERO" ]; then
    "$AEROSPACE" focus --window-id "$WID" 2>/dev/null
    break
  fi
done
]], wezterm_bin, aerospace_bin, jq_bin)
end

-- fzfを使ったセッションセレクター
local function create_fzf_session_selector()
	return wezterm.action_callback(function(window, pane)
		local all_sessions = scan_active_claude_sessions()

		local current_pane_id = pane:pane_id()
		local sessions = all_sessions

		if #sessions == 0 then
			window:toast_notification("Active Claude Code Sessions", "No active Claude Code sessions found", nil, 4000)
			return
		end

		local temp_dir = os.getenv("TMPDIR") or "/tmp"
		local sessions_file = temp_dir .. "/wezterm_claude_sessions_" .. os.time() .. ".jsonl"
		local formatted_file = temp_dir .. "/wezterm_fzf_input_" .. os.time() .. ".txt"
		local result_file = temp_dir .. "/wezterm_claude_result_" .. os.time() .. ".txt"
		local port_file = temp_dir .. "/wezterm_claude_port_" .. os.time() .. ".txt"

		if not export_sessions_to_file(sessions, sessions_file) then
			window:toast_notification("Active Claude Code Sessions", "Failed to export session data", nil, 4000)
			return
		end

		if not export_formatted_sessions_to_file(sessions, formatted_file, current_pane_id) then
			window:toast_notification("Active Claude Code Sessions", "Failed to format session data", nil, 4000)
			os.remove(sessions_file)
			return
		end

		local config_dir = wezterm.config_dir or (os.getenv("HOME") .. "/.config/wezterm")
		local preview_script = config_dir .. "/scripts/preview_claude_session.lua"

		local homebrew_prefix = os.getenv("HOMEBREW_PREFIX") or "/opt/homebrew"
		local path_prefix = homebrew_prefix .. "/bin:/usr/local/bin"

		local fzf_colors =
			"--color=fg:255,bg:-1,hl:117,fg+:255,bg+:237,hl+:141,info:240,prompt:141,pointer:141,marker:141,spinner:141,header:240"

		-- アクティベーションスクリプトを一時ファイルに書き出す
		local activate_script_file = temp_dir .. "/wezterm_claude_activate_" .. os.time() .. ".sh"
		local script_file = io.open(activate_script_file, "w")
		if script_file then
			script_file:write(build_activate_script())
			script_file:close()
		end

		local command = string.format(
			[[PORT=$((RANDOM + 10000)); echo "$PORT" > "%s"; fzf \
        --listen "$PORT" \
        --ansi \
        --height=50%% \
        --reverse \
        --border=rounded \
        --prompt="🤖 Claude Code Sessions > " \
        --preview='export PATH=%s:$PATH; lua "%s" "%s" {}' \
        --preview-window=right:60%%:wrap \
        --delimiter='|' \
        --with-nth=1 \
        %s \
        < "%s" \
        > "%s"; exit]],
			port_file,
			path_prefix,
			preview_script,
			sessions_file,
			fzf_colors,
			formatted_file,
			result_file
		)

		local new_pane = pane:split({
			direction = "Bottom",
			size = 1.0,
			args = { os.getenv("SHELL"), "-lc", command },
		})

		window:perform_action(act.TogglePaneZoomState, new_pane)

		-- 結果処理: ペインが閉じるのを監視し、定期的にセッション情報を更新
		wezterm.time.call_after(0.5, function()
			local refresh_counter = 0

			local function check_pane_closed()
				local tab = window:active_tab()
				if not tab then
					return
				end

				local panes = tab:panes()
				local pane_exists = false
				for _, p in ipairs(panes) do
					if p:pane_id() == new_pane:pane_id() then
						pane_exists = true
						break
					end
				end

				if pane_exists then
					-- 約1秒ごとにセッション情報を再スキャンしてfzfをリロード
					refresh_counter = refresh_counter + 1
					if refresh_counter >= 5 then
						refresh_counter = 0

						sessions = scan_active_claude_sessions()
						export_sessions_to_file(sessions, sessions_file)
						export_formatted_sessions_to_file(sessions, formatted_file, current_pane_id)

						local pf = io.open(port_file, "r")
						if pf then
							local port = pf:read("*line")
							pf:close()
							if port and port ~= "" then
								os.execute(string.format(
									"curl -s -m 1 'http://localhost:%s' -d 'reload(cat \"%s\")' >/dev/null 2>&1 &",
									port,
									formatted_file
								))
							end
						end
					end

					wezterm.time.call_after(0.2, check_pane_closed)
				else
					-- 結果ファイルからpane_idを読み取りアクティベーション
					local rf = io.open(result_file, "r")
					if rf then
						local line = rf:read("*line")
						rf:close()
						os.remove(result_file)

						if line and line ~= "" then
							local target_pane_id = line:match("|([^|]+)$")
							if target_pane_id then
								target_pane_id = target_pane_id:gsub("%s+$", "")
								os.execute(string.format(
									"bash '%s' '%s' '%s' &",
									activate_script_file,
									target_pane_id,
									tostring(current_pane_id)
								))
							end
						end
					end
					os.remove(sessions_file)
					os.remove(formatted_file)
					os.remove(port_file)
				end
			end

			check_pane_closed()
		end)
	end)
end

-- configへの適用
function module.apply_to_config(config)
	-- ウィンドウタイトルにプロジェクト名を含める（AeroSpace でのウィンドウ識別用）
	wezterm.on("format-window-title", function(tab, pane, tabs, panes, config)
		local cwd = pane.current_working_dir or ""
		local path = tostring(cwd):match("file://(.*)") or tostring(cwd)
		local project = path:gsub("/$", ""):match("([^/]+)$") or ""
		if project ~= "" then
			return string.format("%s — %s", pane.title, project)
		end
		return pane.title
	end)

	-- セッション切り替え
	table.insert(config.keys, {
		key = "c",
		mods = "LEADER",
		action = create_fzf_session_selector(),
	})
end

return module
