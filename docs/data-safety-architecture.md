# 数据安全架构设计：私有快照链 + 启动自愈

> 目标：自动备份对用户完全隐形（私有目录、结构化数据、启动动画后静默执行），
> 数据损坏时自动回滚自愈；迁移失败/版本降级时冻结保护数据。
> 手动备份（全量、用户选路径）保持不变。

## 1. 总体分层

```
写入层    原子写入（temp+fsync+rename）          —— 让"半途写坏"不存在
校验层    启动完整性校验（物理/格式/语义）       —— 发现损坏
快照层    私有目录结构化快照链（时间戳命名）     —— 有好的可回滚
修复层    自动回滚 + 修复状态机（暂停快照）      —— 坏了自动恢复
防线层    迁移原子化+失败冻结 / 版本哨兵拒绝     —— 代码/版本错误不伤数据
```

## 2. 快照设计

### 2.1 内容（结构化数据，不含附件/媒体文件）

| 内容 | 来源 | 说明 |
|---|---|---|
| chat_data.json | prefs `conversations`/`active_conversation_id` 等聊天键 | 复用 BackupService |
| settings.json | 其余非 `flutter.*` prefs（配置/版本记录/任务状态） | 复用 BackupService |
| stroom_manifest.json | ManifestDatabase 四类 records + 四类 folders | **records 必须进、媒体文件不进** |
| synthesis/catcatch/background/task_flows 的 tasks/flows/executions.json | AppStorage 目录文件 | **补现有备份缺口** |
| anki/collection.anki2 | AppStorage 根目录 | 备份前 closeOpenedInstance |
| browser_cookies.json | AppStorage 根目录 | |
| manifest.json | 版本/时间戳 | |

- 大小预期：几百 KB ~ 几十 MB（Anki 可能大），远小于全量。
- 格式：**与手动备份相同格式的 ZIP**，恢复直接复用 `BackupService.restoreBackup`
  （含 `migrateDataFormatIfNeeded` 和恢复前校验）。

### 2.2 BackupSelection 扩展

```dart
class BackupSelection {
  ...现有字段不变...
  final bool includeMediaFiles; // 新增，默认 true；false = 只收集记录/结构化数据
  static const structuredOnly = BackupSelection(includeMediaFiles: false);
}
```

- `includeMediaFiles == false` 时：跳过附件循环、媒体文件循环（records 照常收集）。
- 恢复端同样传 `structuredOnly`：附件/媒体文件不动，只恢复结构化数据。

### 2.3 私有目录与命名

```
<AppStorage>/snapshots/
  backup_YYYY-MM-DDTHH-MM-SS.zip     // 时间戳命名，rename 原子落位
  manifest.json                       // {snapshots: [{file, sha256, createdAt, partVersions}]}
```

- 写入链路：`backup_<ts>.tmp` → 校验 → `rename` 为正式名（原子）。
- SHA-256 记录在快照侧 car 清单，恢复前验证，防止快照本身损坏被使用。
- 保留策略：沿用旧逻辑（24h 内保留最新 3 个 + 超 24h 按日历日保留最近 2 天各 1，
  总数上限 5、下限 3），快照与外部 AutoBackups 目录互相独立。

### 2.4 触发时机

- 启动动画完成后静默执行（`startupReady` 之后），**1 小时规则**沿用（最近 1h 有快照则跳过）；
- 迁移前强制快照（无视 1 小时规则）；
- 快照失败 ≠ 数据损坏：只记日志，跳过本次，不进入修复模式。

## 3. 原子写入（Step 1）

- 新工具 `utils/atomic_file.dart`：`writeString`/`writeBytes`（写 `<name>.tmp` → fsync → rename，
  支持并发唯一后缀与重试，参照 background_task_provider 现有模式）。
- 改造点（当前非原子的写入）：
  - `task_provider.dart` `_persistTasks`（synthesis/tasks.json）
  - `catcatch_provider.dart` `_persistTasks`（catcatch/tasks.json）
  - `persistable_notifier.dart` `persist`（task_flows/*.json）
  - `task_session_tracker.dart`（app_launches.json、task_list_last_read.json）
  - `manifest_operations.dart` `writeFile`（媒体文件：同名 hash 半文件会被读到）
  - `attachment_storage.dart` `saveFile/saveEditedFile/saveCompressedImage`
  - `tts_storage_service.dart` `writeFile`
- 已原子：background/tasks.json、browser_cookies.json、备份 ZIP、WebFileStore（IndexedDB 事务）。
- prefs 大键（conversations/provider_entries）：平台写入非原子，无法直接改造 ——
  由快照 + 启动校验 + 损坏隔离（现有 `*.corrupt.*` 机制）兜底，不额外双写。

## 4. 完整性校验（Step 2）

`DataIntegrityChecker`，四层：

| 层 | 检查 | 实现 |
|---|---|---|
| 物理 | SQLite 结构 | `PRAGMA integrity_check`（ManifestDatabase native / Anki） |
| 物理 | JSON 可解析 | conversations/provider_entries/各 tasks.json/cookies 逐键 parse |
| 物理 | 快照完好 | SHA-256 对照 |
| 格式 | 版本兼容 | partVersions ≤ current（超前 → 哨兵）；schema 表结构 |
| 语义 | 硬性不变量 | 记录 ID 非空/唯一、conversations 结构（复用 validateDataFormats） |

- 语义层只查"必然正确"的不变量，不查"记录数"等软指标（防误报回滚）。
- 校验结果分级：`ok / corrupt(可回滚) / versionAhead(哨兵) / frozen(迁移失败)`。

## 5. 修复状态机（Step 4）

状态文件 `<AppStorage>/.data_safety.json`：

```json
{
  "state": "normal | repairing | frozen",
  "failedMigration": "v4→v5 | null",   // 版本感知：仅目标版本==当前版本时冻结
  "lastRepairAt": null,
  "lastSnapshotAt": null
}
```

流程（启动时，数据读取前）：

```
读状态
 ├─ frozen：目标版本==当前 → 冻结页（拒绝进入，可导出）；否则正常（回退旧版场景）
 ├─ repairing：继续上次修复（幂等）
 └─ normal：跑校验
      ├─ ok → （快照按 1h 规则）→ 结束
      └─ 损坏 → state=repairing → 从快照链新到旧：
           SHA 验证 → restoreBackup(structuredOnly) → 再校验
           通过 → 打一版"干净快照" → state=normal
           全失败 → state=frozen（提示手动导入）
```

- 修复期间**暂停自动快照**（防止坏数据覆盖好快照；恢复成功后立刻打干净快照再恢复节奏）。
- 回滚后附件缺失（旧记录引用的文件已删）：静默处理（UI 占位），不阻止回滚、不触发再次回滚。
- 孤儿文件（磁盘有、引用无）：启动时 + 修复后扫描，超 3 天删除，只扫私有目录，
  绝不碰手动备份目录。

## 6. 迁移防线（Step 5）

- 迁移前：**强制快照**（替换现有"迁移前备份到外部目录"）。
- 迁移中：影子/幂等（现有 per-part 幂等设计保留），失败 rethrow（现有）。
- 迁移后：**立即校验** → 失败 → 恢复迁移前快照 → `state=frozen` +
  `failedMigration="vX→vY"` → 冻结页。
- 冻结页：明确提示"数据格式迁移失败，请回退旧版本应用或等待修复版本"，
  允许导出数据（只读），禁止一切写入。
- 回退旧版：旧版读到 `failedMigration` 目标版本 ≠ 自己 → 不冻结，正常使用
  （旧格式数据 + 旧版代码 = 兼容）。

## 7. 版本哨兵（Step 6）

- 启动最早点（任何数据读写前）：`stored[p] > current[p]`（任一 part）→ 拒绝启动页：
  "数据由更新版本的应用创建，请安装更新版本"，提供导出入口，不写任何数据。
- 与冻结的区别：冻结 = 迁移失败（数据是旧格式，旧版可用）；哨兵 = 版本超前
  （数据是新格式，旧版不可读，必须用新版）。

## 8. 清理旧体系（Step 7）

- 删除 `BackupStartupCheck.runCheck` 的授权/空间/备份/弹窗体系；
- `application.dart` 启动后任务改为"静默创建快照"；
- Android SAF 授权流程：自动备份不再使用；SAF 基础设施保留（日志写入 + 手动备份仍需）。
- 旧 AutoBackups 外部目录：不再自动写；用户已有备份文件保留不动（手动导入可用）。

## 9. 平台说明

- 私有目录：Android `/data/data/...`、iOS 沙盒、桌面 AppStorage.directory
  （现有路径体系）；卸载/清数据 = 快照随应用消失 —— 由系统云备份
  （iCloud / 厂商备份）兜底。
- Web：快照走 WebFileStore/IndexedDB，恢复语义一致（校验/回滚同逻辑）。

## 10. 测试计划（Step 8）

1. 原子写入工具：写中断模拟（注入 rename 失败）、并发唯一后缀。
2. 快照轮转/1 小时规则/保留策略（沿用旧测试模式，目录改为私有快照目录）。
3. `structuredOnly` 备份/恢复：记录进、文件不进；恢复后 records 完好、附件不动。
4. 损坏注入：写坏 conversations/库文件 → 启动 → 断言回滚到上一版 + 干净快照 + 恢复自动快照。
5. 全链失败 → frozen + 冻结页。
6. 迁移失败 → 恢复迁移前快照 + frozen + `failedMigration` 版本感知（旧版不冻结）。
7. 版本哨兵：stored>current → 拒绝页；修复版（current 追上）→ 正常。
8. 快照本身损坏（SHA 不符）→ 跳过该版继续往前找。
9. CI：Format/Static Analysis/全部测试分区。

## 11. 实施顺序与提交划分

1. `feat: atomic file writes for data files`（工具 + 7 处改造 + 测试）
2. `feat: data integrity checker`（校验器 + 测试）
3. `feat: structured snapshot chain in private dir`（BackupSelection.includeMediaFiles
   + SnapshotService + 快照缺口补齐 + 测试）
4. `feat: self-healing rollback with repair state machine`
5. `feat: migration freeze and version sentinel`
6. `refactor: remove legacy startup backup/auth/space flow`
7. 全量测试 + 收尾
