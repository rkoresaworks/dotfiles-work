#!/usr/bin/env lua

local sessions_file = arg[1]
local selected_line = arg[2]

-- 色定義
local PURPLE = "\x1b[38;5;141m"
local BLUE = "\x1b[38;5;117m"
local WHITE = "\x1b[38;5;255m"
local GRAY = "\x1b[38;5;240m"
local GREEN = "\x1b[38;5;114m"
local YELLOW = "\x1b[38;5;214m"
local RESET = "\x1b[0m"

-- pane_idを抽出
local pane_id = selected_line:match("|([^|]+)$")

if not pane_id then
	print("Error: Could not extract pane_id")
	os.exit(1)
end

-- jqでJSONパース
local jq_cmd = string.format(
	"grep '\"pane_id\":\"%s\"' '%s' | jq -r '.workspace,.project,.cwd,.content,.tab_title,.status'",
	pane_id,
	sessions_file
)

local handle = io.popen(jq_cmd)
if not handle then
	print("Error: Failed to execute jq")
	os.exit(1)
end

local workspace = handle:read("*line") or ""
local project = handle:read("*line") or ""
local cwd = handle:read("*line") or ""
local content = handle:read("*line") or ""
local tab_title = handle:read("*line") or ""
local status = handle:read("*line") or "idle"
handle:close()

-- ヘッダー表示
print(GRAY .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" .. RESET)
print(PURPLE .. "🤖 Claude Code Session" .. RESET)
print(GRAY .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" .. RESET)
print("")

-- ステータス表示
local status_display
if status == "running" then
	status_display = GREEN .. "● running" .. RESET
elseif status == "waiting" then
	status_display = YELLOW .. "◐ waiting" .. RESET
else
	status_display = GRAY .. "○ idle" .. RESET
end

-- セッション詳細
print(WHITE .. "Status:   " .. RESET .. " " .. status_display)
print(WHITE .. "Workspace:" .. RESET .. " " .. PURPLE .. workspace .. RESET)
print(WHITE .. "Project:  " .. RESET .. " " .. BLUE .. project .. RESET)
print(WHITE .. "Tab:      " .. RESET .. " " .. GRAY .. tab_title .. RESET)
print(WHITE .. "Path:     " .. RESET .. " " .. GRAY .. cwd .. RESET)
print("")

-- セッション内容
if content ~= "" and content ~= "null" then
	print(WHITE .. "Session Content:" .. RESET)
	print("  " .. content)
	print("")
end

-- wezterm cliでペイン出力取得
local wezterm_cmd = string.format("wezterm cli get-text --pane-id %s 2>/dev/null", pane_id)
local wezterm_handle = io.popen(wezterm_cmd)
local pane_output = ""
if wezterm_handle then
	pane_output = wezterm_handle:read("*all") or ""
	wezterm_handle:close()
end

-- 許可待ちの場合、許可プロンプト部分を抽出して強調表示
if status == "waiting" and pane_output ~= "" then
	-- "Do you want to allow" を含むブロックを検出
	local prompt_section = pane_output:match("(─+%s*\n[^\n]*\n[^\n]*\n[^\n]*want to allow[^\n]*\n.*)")
		or pane_output:match("([^\n]*want to allow[^\n]*\n.*)")
	if prompt_section then
		print(YELLOW .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" .. RESET)
		print(YELLOW .. "⚠ Permission Request" .. RESET)
		print(YELLOW .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" .. RESET)
		print("")
		print(prompt_section)
		print("")
	end
end

-- 最新出力
print(GRAY .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" .. RESET)
print(WHITE .. "Recent Output" .. RESET)
print(GRAY .. "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" .. RESET)
print("")

if pane_output ~= "" then
	-- 末尾50行を表示
	local lines = {}
	for line in pane_output:gmatch("[^\n]*") do
		table.insert(lines, line)
	end
	local start = math.max(1, #lines - 49)
	for i = start, #lines do
		print(lines[i])
	end
else
	print(GRAY .. "(Could not retrieve pane output)" .. RESET)
end
