# FourierDraw 实现参考

## 文件结构

```text
FourierDraw.swiftpm/
├── Package.swift          // 不要碰
├── FourierDrawApp.swift
├── Math/       Complex · Resample · DFT · TrailCache
├── Views/      ContentView · PaperCanvas · DrawingLayer · FormulaHeader
│               SineStrip · SpectrumBar · HarmonicSlider · PresetMenu
├── Perf/       PerfTier
└── Presets.swift
```

## 视觉常量

```swift
paper     #F1F0EC    // 纸底
ink       #1A1A18    // 主墨色，重建轨迹
graphite  #7D7A73    // 辅助圆、连杆、手绘笔迹
vermilion #B2352A    // 朱砂
```

**朱砂的语义唯一：当前正被用户操作或选中的量。** 不用于任何装饰，不允许破例。

公式用 `.system(size:design: .serif)`，界面用系统默认无衬线。

## 动画的实现方式

五阶段时序**不是用 `withAnimation` 做的**，是在 `Canvas` 绘制闭包里用 `timeline.date` 算出的纯函数：给定时间 t，算出当前处于哪个阶段、进行到百分之几，所有元素的透明度和半径都是这个百分比的函数。不要引入状态机或动画协调器。

阶段：落笔 → 起稿 0.9s → 运笔（冷启动/预设 6s，手绘后首轮 12s）→ 收笔 0.8s → 翻页 0.5s。
