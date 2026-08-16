# Claude Code

`~/.config/claude/` 是這份 dotfiles 裡**唯一不做整包 symlink** 的模組——同一個目錄底下住著 `.credentials.json`、`sessions/`、`projects/`、`history.jsonl`、`daemon.log`，那些既不該版控、也不該推上公開 repo。

所以這裡是**檔案層 symlink**，只指名四個項目：

| link | 角色 |
|---|---|
| `CLAUDE.md` | 全域指示，套用到所有專案 |
| `RTK.md` | 被 `CLAUDE.md` 以 `@RTK.md` 引入的 RTK 指令參考 |
| `settings.json` | 模型、權限、hook、狀態列 |
| `skills/` | 40+ 個 skill |

`CLAUDE_CONFIG_DIR` 指向 `~/.config/claude` 這件事是在 pwsh 的 `$PROFILE` bootstrap 設的，不在本 repo 管理範圍。

---

## settings.json 的兩個外部依賴

這兩個都**不是 winget 能裝的**，由 `install.ps1` 的階段 3 處理（寬容失敗——它們壞掉只影響 Claude Code 的外觀與 hook，終端機本身不受影響）：

| 依賴 | 安裝 | settings.json 怎麼用它 |
|---|---|---|
| `ccstatusline` | `npm i -g ccstatusline`（需 Node.js） | `statusLine.command`，外觀設定在 `~/.config/ccstatusline/settings.json` |
| `rtk` | `cargo install --git https://github.com/rtk-ai/rtk`（需 rustup） | `PreToolUse` hook `rtk hook claude` |

**`rtk` 有名稱衝突**：crates.io 上另有一個 `rtk`（reachingforthejack／Rust Type Kit）。必須用上面的 git URL 安裝，裝錯的話 `rtk gain` 會找不到指令。

`statusLine.command` 裡寫的是絕對路徑（`C:/Program Files/nodejs/node.exe` 與 npm 全域目錄）。**刻意不改成可攜寫法**：這份 dotfiles 的使用場景是單機重灌還原，重灌後這兩個路徑完全一致，而改成未經驗證的簡寫是零收益的風險。

---

## 權限規則

`settings.json` 的 `permissions` 分三層，重點在 `deny` 那段——它擋掉的是**不可逆**的操作，不是「危險」的操作：

- `git push --force` / `reset --hard` / `clean -f` / `branch -D` / `checkout .` / `restore .`
- `rm -rf`、`Remove-Item * -Recurse *`
- 讀取 `~/.ssh`、`~/.aws`、`~/.gnupg`、`**/.env`、`.credentials.json`

每條 git 規則都寫了三個變體（`Bash(git …)`、`Bash(rtk git …)`、`PowerShell(git …)`），因為 RTK hook 會把 `git status` 改寫成 `rtk git status`，只擋原形會漏。

> 這些 deny 規則會實際擋住 Claude Code 自己的操作。維護這份 repo 時如果撞到「Permission denied」，多半就是踩到這裡——換一個不觸發規則的做法（例如用 `git rm -r` 而不是 `Remove-Item -Recurse`）通常才是更對的工具。

---

## skills/

41 個 skill，其中部分是第三方公開作品（`ask-matt`、`setup-matt-pocock-skills` 等）。這些是**全域** skill，每個專案都會載入。

### 本 repo 自己的 skill 不放這裡

維護規則寫成 `skills/dotfiles/SKILL.md`，留在 repo 內、**不部署出去**：

| | 位置 | 範圍 |
|---|---|---|
| 全域 skill | `home/.config/claude/skills/` → symlink 到 `~/.config/claude/skills/` | 所有專案都會載入 |
| 本 repo 的維護規則 | `skills/dotfiles/` | 只屬於這個 repo |

判準是「這條規則對別的專案有意義嗎」。symlink 模型、`$Transparent` 怎麼加、什麼不該收——這些只在維護 dotfiles 時有用，放進全域只會污染每一個 session 的 skill 清單。
