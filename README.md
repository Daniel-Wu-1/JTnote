# JTnote

JTnote 是一款面向 Windows 的本地笔记软件，核心目标是快速记录、可靠保存、低打扰使用。它使用 Tauri 2、React、TypeScript、TipTap 和 SQLite 构建，笔记、设置、图片和备份都保存在本机，不内置云同步、统计上报或远程服务。

## 主要功能

- 完整主窗口：笔记列表、搜索、置顶、拖拽排序、右键操作、设置、导入和导出。
- 快捷精简窗口：可用鼠标中键或全局快捷键呼出，适合临时记录；支持失焦自动保存并隐藏。
- 同一套数据：主窗口和精简窗口只是同一笔记系统的两种显示方式，不是两套独立数据。
- 富文本编辑：标题、正文、粗体、斜体、下划线、删除线、字号、颜色、高亮、列表、任务列表、引用、代码块、链接和图片。
- 原生右键菜单：编辑器格式菜单和笔记列表菜单使用 Tauri 原生菜单，避免 WebView 边界裁切。
- 本地图片管理：粘贴或插入图片会保存到本机图片目录，并按笔记 ID 与标题归档。
- 导入导出：支持 txt、md、html、json、docx 导入；支持 txt、md、html、json、docx、pdf 导出。
- JSON 全量备份：可导出笔记、设置和图片，导入后会恢复图片在正文中的原位置。
- 自动保存：输入防抖保存、失焦保存、退出前保存、本地草稿兜底。
- 自动备份：启动时检查 SQLite 数据库并按周期生成一致快照。
- 多语言：首次运行会按系统语言自动选择界面语言；不支持的语言默认英文。

## 使用方式

启动后，主窗口左侧是笔记列表，右侧是编辑区域。点击“新建”即可创建笔记，输入内容会自动保存。左侧笔记可右键打开菜单，支持删除、导出、复制、置顶等操作；拖动笔记项可调整排序，置顶笔记只在置顶组内排序。

精简窗口可通过设置中的触发方式呼出。默认适合快速记录，关闭逻辑为右上角关闭按钮、Esc、Ctrl+Enter 或失去焦点自动保存隐藏。插入图片、选择颜色、使用右键菜单等软件内部操作不会主动关闭精简窗口。

## 数据位置

默认数据目录：

```text
%APPDATA%\com.jtnote.app\
```

常见文件和目录：

- `notes.db`：主 SQLite 数据库。
- `notes.db-wal`、`notes.db-shm`：SQLite WAL 运行文件。
- `settings.json`：主题、语言、触发方式、快捷键等设置。
- `images\`：本地图片根目录。
- `images\<笔记ID>-<笔记标题>\`：对应笔记的图片目录。
- `images\_draft\`：新笔记首次保存前的临时图片目录。
- `backups\`：自动备份目录。

图片文件以 SHA-256 内容哈希命名，因此同一张图片不会重复写入。笔记文件夹名包含笔记 ID，即使多个笔记标题相同也不会冲突。删除笔记时会清理该笔记 ID 对应的图片目录；列表刷新时也会节流清理旧版本残留的孤儿图片目录。

## 自动备份

JTnote 启动时会检查数据目录中的 `backups\`。如果 7 天内没有新的备份，会通过 SQLite online backup API 生成一致快照，文件名类似：

```text
notes.2026-06-10_120000.sqlite
```

默认保留 4 份最新备份，旧备份会自动清理。使用 SQLite online backup API 的原因是：即使数据库处于 WAL 模式，也能得到一致的数据库快照，而不是简单复制可能不完整的 `notes.db` 文件。

恢复备份：

1. 退出 JTnote。
2. 打开 `%APPDATA%\com.jtnote.app\`。
3. 备份当前 `notes.db`、`notes.db-wal`、`notes.db-shm`。
4. 从 `backups\` 中选择要恢复的 `notes.*.sqlite`。
5. 将该文件复制为 `notes.db`。
6. 删除旧的 `notes.db-wal` 和 `notes.db-shm`。
7. 重新启动 JTnote。

自动备份只备份 SQLite 笔记数据库；图片目录仍在 `images\` 中。迁移到新电脑时，更推荐使用设置里的“导出全部为 JSON 备份”，它会把笔记、设置和图片数据放入同一个 JSON 文件。

## 导入与导出

单条笔记可导出为 txt、Markdown、HTML、JSON、Word 或 PDF。单条 JSON 会包含该笔记和正文中引用的图片数据。

全量导出会生成一个 JSON 备份，包含：

- `settings`：应用设置。
- `notes`：所有笔记内容。
- `images`：图片文件名、MIME 类型、原始引用和 base64 数据。

导入 JSON 备份时采用合并模式：会把备份中的笔记追加为新笔记，不覆盖当前已有笔记。图片会自动恢复到本机图片目录，并替换正文中的旧图片引用，使图片仍出现在导出前的位置。

## 保存逻辑

编辑器输入会先写入本地草稿，再通过防抖自动保存到 SQLite。切换笔记、失去焦点、关闭窗口或从托盘退出时都会尝试保存。保存写入是串行化的，避免快速输入、切换笔记和窗口关闭同时发生时产生并发写入或重复新建。

如果保存失败，界面会显示错误状态，草稿不会被清除。下次打开对应笔记或新建草稿时，应用会尝试从 localStorage 恢复未保存内容。

## 性能设计

- 笔记列表只加载标题、摘要、时间和正文大小，完整正文只在打开笔记或导出时读取。
- 富文本编辑器使用懒加载，进入编辑状态时才加载 TipTap 相关代码。
- 导入、导出、Word、Markdown 转换等低频功能按需加载。
- 图片统计带缓存，图片目录清理做节流处理。
- 数据库使用 WAL、`synchronous=NORMAL` 和 FTS5 trigram 搜索。
- 代码高亮引擎已移除，保留代码块功能，减少编辑器体积和启动负担。

## 安全与健壮性

- 导入 HTML、Markdown、DOCX、JSON 和编辑器保存内容都会经过 HTML 净化。
- 链接只允许 `http`、`https` 和 `mailto`。
- 图片 asset 访问范围限制在应用配置目录的 `images` 下。
- Tauri CSP 限制脚本、资源和 frame 来源。
- 删除笔记前有确认弹窗，避免误触。
- 全局快捷键注册失败会在界面提示，用户可改用其它组合键。

## 开发环境

推荐环境：

- Windows 10/11
- Node.js 20 或更新版本
- Rust stable MSVC toolchain
- Visual Studio 2022 Build Tools，包含 C++ build tools 和 Windows SDK
- Microsoft Edge WebView2 Runtime

安装依赖：

```powershell
npm install
```

开发运行：

```powershell
npm run tauri dev
```

前端构建：

```powershell
npm run build
```

完整打包：

```powershell
npm run tauri build
```

如果 PowerShell 找不到 Cargo：

```powershell
$env:PATH="$env:USERPROFILE\.cargo\bin;$env:PATH"
```

## 发布检查

发布前建议执行：

```powershell
npm run build
npm audit --audit-level=moderate
cd src-tauri
cargo check
cargo clippy --all-targets -- -D warnings
cd ..
npm run tauri build
```

构建产物位置：

- 绿色版 exe：`src-tauri\target\release\jtnote.exe`
- NSIS 安装包：`src-tauri\target\release\bundle\nsis\`
- MSI 安装包：`src-tauri\target\release\bundle\msi\`


## 常见问题

快捷键注册失败：组合键被其它程序占用，请在设置中换一个快捷键。

精简窗口刚呼出就隐藏：适当增大“失焦保存延迟”，推荐 80-300 毫秒。

主窗口空白：确认 Microsoft Edge WebView2 Runtime 已安装或修复。

搜索异常：退出并重新打开应用，启动时会检查并修复 FTS 索引结构。

图片无法显示：确认 `%APPDATA%\com.jtnote.app\images\` 没有被清理工具删除。

导入 JSON 后没有图片：旧备份可能不包含图片数据，或外部图片路径在当前电脑不可访问。使用 JTnote 的全量 JSON 导出可以确保图片被内嵌到备份中。
