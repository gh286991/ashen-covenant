# Mac Debug 卡頓修正（2026-09-07）

## 原因與修改

在 Apple M1 Pro、Godot 4.5.1 Mono 的 Debug 執行檔重現卡頓。初步隔離測試中，正常場景約 60.6 ms/frame，暫停所有 AnimationPlayer 後約 17.5 ms/frame；物理運算約 1–2 ms。更換繪圖後端、保留動畫與陰影後約 6 ms/frame。結果指向這個場景在 macOS OpenGL Compatibility 下的動態模型繪製成本，並非必須關掉 Debug 才能改善。

- macOS 改用 Forward Mobile + 原生 Metal。一般／Web／行動裝置的相容後端設定保留。
- 啟用角色、敵人和箭矢的物理插值；角色動畫改在物理更新中播放。
- 鏡頭在每個畫面更新時追蹤角色的插值位置，避免直接讀取每秒 60 次的階梯狀位置。
- 傳送後重設插值，短暫使用目的地位置避開同幀快取，防止鏡頭回跳。
- 地城根節點關閉插值，只有物理移動的分支開啟；畫面更新驅動的特效不套用物理插值。玩家血條方向與物理更新同步。
- 未刪除場景裝飾、減少模型細節或關閉陰影。不同後端的材質亮度／高光呈現略有差異，已檢視實際畫面。

## 可重現測量

工具：`tools/profile_dungeon_performance.gd`。固定 1280×720 渲染尺寸、關閉 VSync、固定亂數種子，暖機 4 秒後測量待機、往返走路、換至 B 房各 4 秒。玩家在測試期間無敵；敵人 AI 和動畫持續運作。兩個後端依序執行，沒有同時執行其他測試遊戲。

以下是同一份修正後程式，以命令列強制舊後端，與預設 Metal 後端的比較；不是不同硬體的效能保證。AI／物理在低幀率時的演進會有差異，繪製呼叫數不能視為同一影格的精確比較。

| 情境 | Compatibility 平均 ms | Metal 平均 ms | Metal P95 ms | Metal 超過 16.67 ms 比例 |
|---|---:|---:|---:|---:|
| idle | 69.75 | 5.19 | 6.71 | 0.00% |
| walking | 101.09 | 6.57 | 9.85 | 0.16% |
| room_b | 194.42 | 9.04 | 11.25 | 0.68% |

一般遊戲仍使用原本的 VSync；測試中高於螢幕更新率的 FPS 代表效能餘裕。數字不含首次載入和首次材質編譯。

重跑：

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . --script tools/profile_dungeon_performance.gd
/Applications/Godot_mono.app/Contents/MacOS/Godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script tools/profile_dungeon_performance.gd
```

## 驗證與限制

通過：

- `validate_dungeon_mouse_combat.gd`：重攻擊、游標瞄準、Shift 攻擊、地面移動、寶箱接近與開啟動畫。
- `validate_dungeon_enemy_attacks.gd`：近戰、獵犬交替攻擊、弓箭發射時機與次數。
- `validate_dungeon_interpolation.gd`：以 10 Hz 物理更新和 120 FPS 上限放大差異，確認物理更新間仍有平滑位置；兩次換房不回跳，特效維持畫面更新模式。
- `validate_level_up_celebration.gd`：升級動畫、粒子、文字與獎勵事件。
- `git diff --check`。

兩支舊驗證尚不能通過：`validate_dungeon_3d.gd` 硬性要求已不存在的 `Sword_Attack` 舊動畫；`validate_combat_feedback_3d.gd` 引用已移除的 `CryptWraith_A1/A2` 舊場景節點。這些檔案本次沒有修改，也未把結果列為通過。

結束整個地城測試時，仍出現原有的 Rendering RID／ObjectDB 資源清理警告；修改前的隔離測試也有同類訊息。本次沒有處理此獨立的退出清理問題。

已保留工作區原先未提交的場景與方尖碑資產修改。本次沒有匯出或部署新版。現有 Godot 編輯器如仍沿用舊的繪圖後端，重開專案後再啟動 Debug。

技術依據：[Godot 4.5 鏡頭插值](https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/advanced_physics_interpolation.html)、[平台設定覆寫](https://docs.godotengine.org/en/4.5/tutorials/export/feature_tags.html)。
