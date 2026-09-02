# FourierDraw V2 Codex Prompt 包（20–26）· rev.2

**修订于 2026-09-02，据实现方 code review 修正。rev.1 作废。**
主要更正见文末「rev.1 → rev.2 更正表」。

---

## 使用方式

一次复制一个 prompt。每个 prompt 结尾都写了"你应该看到什么"，那是验收信号，看不到就不要往下走。

**每轮开场必贴**（放在 prompt 正文前面）：

> 先读仓库根目录的 `AGENTS.md` 和 `V2_SCOPE_LOCK.md`。V2 是纯增量，不重构任何已通过验证的代码。
> 先完整读一遍我指定的那个文件，输出一份 plan：你打算保留哪些既有属性和方法、新增哪些、为什么。等我批准再写代码。
> **每一步只改一个文件。** 跨文件的 prompt 我已经拆成有序子步骤，每一步单独编译，不许合并。
> 输出完整文件内容不要 diff，改完必须编译，零 error 零 warning。

---

## 通用约束

- 只 import SwiftUI / Foundation / CoreGraphics
- 目标 iOS 17，不用 beta API，**不用 `.glassEffect()` 之类 iOS 26 才有的东西**
- 不碰 `Package.swift`，不建 target，不加依赖
- **`Math/` 整个目录只读**，包括 `TrailCache.swift`
- 颜色只用既有六槽位：`paper #F1F0EC` / `ink #1A1A18` / `graphite #7D7A73` / `vermilion #B2352A` / `panel` / `muted`
- 公式与数值用 `.system(size:design: .serif)`，界面文字用系统无衬线
- 坐标一律从 `GeometryReader` 推导，禁止基于设备型号判断

### 路径

`ContentView.swift` 当前在 **`FourierDraw.swiftpm/` 根目录**，不在 `Views/` 下。
下面的 prompt 只写文件名，**改之前先在仓库里定位实际路径**，不要按目录树臆测，更不要新建同名文件。

---

## Prompt 20 — iPad 常规宽度布局（`ContentView.swift`）

**这是一次纯新增的分支，不要改动任何既有布局分支。**

现有布局有两个分支：窄屏（< 500pt，讲义倒序）和常规宽度（≥ 500pt，右侧栏）。
本次新增第三个：**宽度 ≥ 900pt 时走 iPad 横屏布局**。500–900pt 的既有代码路径一行都不要动。

结构（以 1180 × 820pt 为基准，全部从 `GeometryReader` 推导）：

```
页面外边距 24
标题块   圆之绘 22pt ink ／ 副标题 13pt ink 55%
发丝线   ink 10%，1pt，通栏
内容行（HStack，spacing 36）
  ├ 画布列  占剩余宽度（1180 时约 680pt）
  └ 右侧列  固定 416
       公式 30pt serif
       |k| ≤ M  21pt serif，M 朱砂
       逐符号释义四行（Prompt 21 填）
       发丝线
       正弦条  波形区不得小于 240pt
       发丝线
       平均偏离读数（Prompt 25 填，本轮先留空位）
内容行与面板间距 28
浮层面板  通栏，高 172，圆角 22
       阶数 |k| ≤ M    共 N 项参与        ⊖  ⊕
       频谱 65 根，左右各留 20pt padding
       −32      −16      k = 0      +16      +32
       滑块，与频谱同宽
```

面板沿用既有规格：`Color.white.opacity(0.78)` + `.ultraThinMaterial`，1px `ink.opacity(0.12)` 描边，零阴影。

三条硬约束：

1. **纸底仍铺满全屏并延伸到面板背后**，这是"分层不分区"，不要改成三个分区
2. **公式与正弦条印在纸上，不许放进浮层面板**
3. 频谱柱心间距在 1180pt 下应约 17pt。命中测试**仍是整条挂一个 `DragGesture` 用 `location.x` 反查最近的 k**，不要逐根铺热区

**验收信号**：iPad 横屏模拟器（或 Mac 窗口拉到 1100pt 以上）里，频谱和滑块在屏幕底部通栏，65 根柱清晰可数，画布明显变宽。拉窄到 800pt，无缝回到原右侧栏布局，且原布局外观零变化。

**最容易错**：把新分支写成改造旧分支。发现自己在动 500–900pt 那段代码，停下重做。

---

## Prompt 21 — 公式逐符号释义（`FormulaHeader.swift`）

公式下方新增四行释义，符号列衬线体，释义列无衬线：

| 符号 | 释义 |
|---|---|
| `cₖ` | 这个圆有多大 |
| `e^(i2πkt)` | 转多快、朝哪边转 |
| `Σ` | 把它们首尾接成一条链 |
| `\|k\| ≤ M` | 链子只搭到第 M 阶为止 |

- 符号列 15pt serif，`ink` 90%；释义列 13pt sans，`ink` 62%
- 行距 28pt，符号列左对齐于公式左边缘，释义列固定缩进 106pt
- 第四行的 M 跟随滑块实时变化，**但不上朱砂**——多一个红数字会稀释主公式那个
- 上下标用 `Text` 拼接（`+` 运算符）加 `.baselineOffset`，不要手工摆 `x` 坐标，Dynamic Type 一开就散
- 支持 Dynamic Type；超宽时释义列允许换行，符号列不换行

窄屏分支（< 500pt）也显示，但改为 11pt、行距 22pt。

**验收信号**：公式下面四行对照，拖滑块时第四行数字跟着变且是灰的。系统字号调到最大，不重叠不出界。

---

## Prompt 22 — 画布锚点标注与转向弧（两个文件，按序）

### 22.1 第一步 · `PaperCanvas.swift` 绘制

两件事，都画在 `Canvas` 绘制闭包里，都是 `timeline.date` 的纯函数，不引入新状态。

#### 三条锚点标注

每条是「符号 + 两三个字的大白话」，一条 1pt `ink.opacity(0.26)` 引线连到它命名的东西，锚点端一个 1.9pt 实心点。

| 锚点位置 | 标注文字 |
|---|---|
| 半径最大的已绘制圆，其半径线段中点 | `cₖ` 半径 |
| 同一个圆上、相对当前相位偏 150° 的圆周点 | `e^(i2πkt)` 转速与方向 |
| 圆链最后一段可见连杆的中点 | `Σ` 把这些圆首尾接起来 |

**标签必须落在原稿幽灵路径包围盒之外。** 做法：先算幽灵路径包围盒，再在左侧 / 上方 / 下方边距里挑一个不与包围盒相交的位置，并夹紧在画布可见范围内。**不许硬编码坐标**——图形是用户画的，每次都不一样。

标注 12pt。容器高度 < 560pt 时全部隐藏。

**不要用 ①②③ 编号。** 编号服务于序列，这里是对应关系。

#### 转向弧

对屏幕半径 > 26pt 的已绘制圆，在半径 + 8pt 处画约 54° 的弧，末端加 6pt 三角箭头，`graphite` 60%。

**正频率画面上逆时针，负频率顺时针。** 写完在注释里说明你怎么确定方向的，包括屏幕 y 轴向下这一层翻转。

#### 无障碍边界（rev.2 更正）

`Canvas` 里画出来的文字**不是**独立的 SwiftUI 无障碍元素，不要试图给它们各挂一个 `accessibilityLabel`。

正确做法：给整张画布一个合并后的 `accessibilityLabel`，内容随状态生成，例如

> 圆链共 13 个圆。最大的圆半径 105，代表系数 c 下标 k。圆按各自频率旋转，正频率逆时针，负频率顺时针。所有圆首尾相接，末端就是笔尖。

### 22.2 第二步 · `ContentView.swift` 更新无障碍描述

当前整张画布的 `.accessibilityElement(children: .ignore)` 和 `.accessibilityLabel(...)` 挂在 `ContentView` 外层，不在 `PaperCanvas` 内。因此只改 `PaperCanvas.swift` 不会生效。

只扩展既有的 `canvasAccessibilityLabel`，使它覆盖参与圆数、最大圆半径、旋转方向与首尾相接。不新建第二套无障碍树。

**验收信号**：三条带引线的标注落在图形外侧空白处、不压墨迹；最大的圆外侧有带箭头的弧。换三个预设（五角星 / 心形 / 正方形）、再手绘一个歪扭形状，标注自动避让。打开 VoiceOver，画布朗读为一句完整描述。

---

## Prompt 23 — 步进按钮与中心向外滑块（`HarmonicSlider.swift`）

### 23.1 实现方式（rev.2 明确）

不要试图给原生 `Slider` 换皮。做法是：

```
ZStack {
    自绘的视觉轨道（中心向外的填充、中点刻度、左侧镜像指示点、右侧 knob）
    Slider(value:in:onEditingChanged:).opacity(0.02)   // 只负责手势与无障碍
}
```

原生 `Slider` 保持存在但视觉上不可见，**手势、Dynamic Type、VoiceOver 全部由它承担**，不要自己包 `DragGesture`。

视觉轨道规格：轨道通栏；中点画一条 1pt 刻度对齐频谱的 k = 0；填充从中点向两侧延伸到 \(\pm p \cdot \text{半宽}\)；右侧 knob 半径 10（拖动中 13），左侧镜像指示点半径 7、`ink` 28%、不响应手势。

> 滑块用 \(p^2\) 映射、频谱是线性 k 轴，两条刻度**不会严格对齐**。这是已知取舍，不要为对齐改映射公式。

### 23.2 步进按钮

面板标签行右端一对按钮，左边一行 11pt 灰字「一阶一阶看」。

- 各 28pt 直径，热区补足 44 × 44
- ⊖ 令 `M -= 1`，⊕ 令 `M += 1`，夹紧 1…256
- VoiceOver 标注「降低一阶」「提高一阶」

**映射换算是唯一的坑。** 绑定值是 \(p\)，而 \(M = \mathrm{round}(1 + 255p^2)\)，步进必须走反函数：

\[
p' = \sqrt{\frac{M' - 1}{255}}
\]

写完加临时断言：对 M 从 1 遍历到 256，`round(1 + 255 * pow(inverse(M), 2)) == M` 必须全部成立。**把 print 输出贴给我**，不要口头说通过。

### 23.3 为差量高亮预留唯一的事件通道

新增回调，并把默认值放在**显式初始化方法的参数**上：

```swift
private let onIncrease: (Int, Int) -> Void

init(
    m: Binding<Int>,
    isDragging: Binding<Bool>,
    participating: Int,
    onIncrease: @escaping (Int, Int) -> Void = { _, _ in }
) {
    _m = m
    _isDragging = isDragging
    self.participating = participating
    self.onIncrease = onIncrease
}
```

不要只给存储属性一个默认闭包；后续 Prompt 24 必须能通过初始化方法注入回调。

按 ⊕ 时先计算 `oldM` / `newM`，确认没有超出 256 后，先调 `onIncrease(oldM, newM)`，再更新 M。⊖、原生 Slider 与 VoiceOver 调整都不调这个回调。

**验收信号**：连按五次 ⊕，阶数一次涨一格，墨迹每次有可见变化；断言 print 全绿；拖动手感与改造前一致。

---

## Prompt 24 — 阶数差量高亮（三个文件，严格按序）

**触发条件（rev.2 收紧）：只由 ⊕ 单步触发。** ⊖、连续拖动、轮播、切预设、手绘完成一律不触发。
这样新增集合恒为 `{+M₁, −M₁}`，唯一例外是 `M₁ = 256` 时只有 `−256` 一项，读数模板因此安全。

### 24.1 第一步 · `ContentView.swift` 存状态并快照旧轨迹

新增三个属性：

```swift
@State private var previousTrail: [CGPoint] = []
@State private var deltaShownAt: Date? = nil
@State private var deltaAddedFreqs: [Int] = []
```

**关键（rev.2 更正）**：在初始化 `HarmonicSlider` 时接上 Prompt 23 的 `onIncrease`。`previousTrail` 是**在 M 改变之前，直接把当前已算好的 trail 数组原样存一份**。
不要在画布里用 `previousM` 重算——`ContentView` 每次重建都会新建临时 `TrailCache` 用完即弃，画布拿不到历史缓存，重算只能每帧新建缓存，必然掉帧。
不要在 `onChange(of: m)` 里推测事件来源；那会把 Slider、VoiceOver 或其他 M 变化误当成 ⊕。

⊕ 被按下时的顺序：

```
1. previousTrail = 当前 trail
2. deltaAddedFreqs = { k : |k| ≤ M₁ } \ { k : |k| ≤ M₀ }
3. deltaShownAt = .now
4. 再更新 M 并重建 trail
```

`deltaAddedFreqs` 从**实际频率集合取差集**，不要用 `2M+1` 推算。

**不要新增"是否正在展示差量"这类布尔。** 它就是 `deltaShownAt` 距今是否小于 0.9s，多存一个会产生两个可能不一致的真相来源。

验证：临时 print。3 → 4 应输出 `added [4, -4]`；255 → 256 应输出 `added [-256]`，只有一项。

### 24.2 第二步 · `PaperCanvas.swift` 画高亮

新增三个入参：`previousTrail: [CGPoint]`、`deltaAddedFreqs: [Int]`、`deltaShownAt: Date?`。

给定 `timeline.date`，算 `elapsed`，若 `elapsed < 0.9s`：

- `deltaAddedFreqs` 里那几个圆改用 `vermilion` 描边，线宽 1.6，透明度 0.95
- 把 `previousTrail` 以 `ink.opacity(0.09)`、线宽 2.2 画在墨迹下层
- 两者透明度在最后 0.3s 内线性褪回

**画布只负责画，不做任何重算。** `previousTrail` 是现成的点数组，直接连线。

**0.9s 后朱砂必须完全消失。**

### 24.3 第三步 · `FormulaHeader.swift` 出读数

差量窗口内，公式下方插入三行：

```
+2 项      k = +4 和 k = −4          ← "+2 项" 朱砂，其余 ink 80%
半径 9.2 pt 与 3.8 pt                ← 11pt，ink 60%
两边频率对称，半径通常并不相等          ← 11pt，ink 50%，常驻不随差量消失
```

半径数值 = \(|c_k| \times s\)，`s` 是全工程共享的缩放系数，不要另算一个。
第三行是常驻教学文案，差量褪去后留在原地。

**验收信号（三步全做完再验）**：按一次 ⊕，同时看到四件事——新的两个圆变红、旧墨迹留一道灰影、公式下方出现 `+2 项 k = …`、0.9 秒后红色干净褪尽。任何一件没发生就停下来查，不要往下做。

---

## Prompt 25 — 平均偏离读数（两个文件，按序）

### 25.0 定义（rev.2 更正，务必先读）

rev.1 用的是最大逐点误差并要求它随 M 单调下降。**那个量不单调**，在本工程测试形状上 M = 17、20、28、30 处即回升，验收永远过不了。

改用**尾部能量 RMS**。由 Parseval：

\[
E(M) = \sqrt{\sum_{|k| > M} \left| c_k \right|^2}
\]

每加一阶就从尾部减去一个非负项，**全域严格非增**，M ∈ [1, 256] 已全量验证零反例。

**这不需要碰 `TrailCache`，不需要遍历轨迹采样点。** `Math/` 保持完全只读。

### 25.1 第一步 · `ContentView.swift`

不建后缀表。M 或 `cycles` 变化时，遍历现有 512 个 `Epicycle`，累加 `abs(freq) > M` 的 `amp * amp` 并开平方。这点开销相对轨迹重建可以忽略，不为 O(1) 查表增加一份缓存状态。

新增的状态存**数学坐标系下的平均偏离**，不提前乘屏幕缩放系数：

```swift
@State private var deviation: Double = 0
@State private var previousDeviation: Double? = nil   // 只在差量窗口内非 nil
```

读数**只在 ≥ 900pt 的新 iPad 布局显示**。新布局已知画布尺寸，直接调用现有共享纯函数 `paperScale(for:in:)`，把 `deviation * scale` 传给 `FormulaHeader`。这个函数已存在，**不要再提取、不要在布局分支里复制缩放公式**。

窗口或画布大小变化时，数学偏离不变，但 pt 读数会用当前 scale 自动重算。**绝对不要把该计算放进 `Canvas` 绘制闭包**。

验证：临时 print，对 M 从 1 到 256 打印 `deviation`，确认全域非增，把开头十行和结尾十行贴给我。

### 25.2 第二步 · `FormulaHeader.swift` 显示

右侧栏底部三行：

```
墨迹与原稿的平均偏离              12pt，ink 50%
5.0 pt                          26pt serif，ink 90%
阶数每加一阶，这个数不会变大        11pt，ink 42%
```

保留一位小数。差量窗口内改为 `14.8 → 11.0 pt`，箭头右边那个数上朱砂，0.9s 后回到单值。
文案必须用「不会变大」：某阶系数可能为零，而且保留一位小数后，相邻两阶可能显示相同数值。

**不要再叫「最远差」。** 那是另一个量，且它不单调。

> 备选口径：若你更想要一个百分比，可改为「还原度 \(1 - E(M)/E(0)\)」，同样严格单调。二选一，不要两个都放。

**验收信号**：拖滑块时数字严格不回升，拖到 256 趋近 0；print 输出确认全域非增；拖动依然跟手。

---

## Prompt 26 — 首轮引导字幕（两个文件，按序）

**rev.2 已砍掉跨组件联动。** rev.1 曾要求同时做圆链提亮 / 连杆闪 / 滑块跳，那需要改 `PaperCanvas` 和 `HarmonicSlider`，且工程里两个 `TimelineView` 分别封装在画布和正弦条内部，不存在可复用的共享 timeline。**只做三句字幕，不做任何跨组件动作。** 字幕本身已经能完成教学目标。

### 26.1 第一步 · 新建 `FirstRunCaptions.swift`

一个自包含视图，入参只有 `startedAt: Date` 和 `onFinished: () -> Void`。`TimelineView` 只根据时间计算当前第几句，不在绘制闭包或 `body` 计算过程里调回父状态。

内部自带 `TimelineView(.periodic(from: startedAt, by: 0.1))` 驱动，**不要去找或建立共享 timeline**。结束由下面的 `.task` 负责：

```swift
.task {
    do {
        try await Task.sleep(for: .seconds(8))
    } catch {
        return
    }
    onFinished()
}
```

视图提前移除时 `.task` 会自动取消。不要写成 `try? await Task.sleep(...)`：它会吞掉 `CancellationError` 并继续调用 `onFinished()`。自然播完后由父视图把整个视图从层级移除。

| 时刻 | 字幕 |
|---|---|
| 0.0 s | 每个圆是求和式里的一项 |
| 2.5 s | 圆首尾相接，末端就是笔尖 |
| 5.0 s | 拖下面的滑块，看它用几个圆 |
| 8.0 s | 整体淡出并移除 |

卡片：宽度 = 画布宽度的 0.72，高 52，圆角 16，`Color.white.opacity(0.80)` + 1px `ink.opacity(0.10)` 描边，零阴影。文字 16pt sans、`ink` 90%、居中。下方三个 3pt 圆点标进度，当前项 `ink` 75%，其余 22%。

`.allowsHitTesting(false)` —— 它不拦任何交互，不加按钮，不加关闭叉。

`accessibilityReduceMotion` 打开时照常显示三句，去掉交叉淡入直接切换。

### 26.2 第二步 · `ContentView.swift` 接线

- 新增 `@State private var hasDismissedCaptions = false`
- 任何一次触摸画布、拖滑块、按步进、点频谱、点预设，都置 true 并立即移除字幕
- `onFinished` 同样只把 `hasDismissedCaptions` 置 true
- `hasDismissedCaptions == false` 时才渲染 `FirstRunCaptions`
- 一个布尔值统一表达「字幕已结束」，无论原因是用户交互还是自然播完

**验收信号**：冷启动依次出现三句；中途碰一下屏幕，字幕立刻消失且不再出现；字幕存在期间画布手绘、滑块拖动都正常响应（说明没拦手势）。

---

## rev.1 → rev.2 更正表

| # | rev.1 | rev.2 |
|---|---|---|
| 1 | M4 用最大逐点误差，要求单调下降 | 改用尾部能量 RMS，可证严格非增 |
| 2 | M4 允许给 `TrailCache` 新增方法 | 撤销，`Math/` 完全只读 |
| 3 | M2 在画布里用 `previousM` 重算旧轨迹 | 改为 `ContentView` 快照 `previousTrail: [CGPoint]`，画布只画 |
| 4 | Prompt 25 只列两个文件 | 补上 `ContentView`，拆成两个有序子步骤 |
| 5 | Prompt 26 含三个跨组件闪动 | 全砍，只保留三句字幕；字幕自带独立 timeline |
| 6 | 差量高亮响应"任何 M 变化" | 收紧为只由 ⊕ 单步触发 |
| 7 | 「只有 Prompt 24 可跨文件」 | 改为「每一步只改一个文件；跨文件 prompt 拆成有序子步骤」 |
| 8 | 路径写成 `Views/ContentView.swift`；AGENTS.md 写成包内 | 更正为包根目录 / 仓库根目录，且只追加不新建 |
| 9 | Prompt 23 未指定滑块实现方式 | 明确为自绘轨道 + 透明原生 Slider 承担手势与无障碍 |
| 10 | 锚点标注要求三个独立 a11y label | 改为整张画布一个合并描述 |

---

## 收口检查

跑完 20–26 之后，回到既有的 Prompt 18（无障碍与降级）和 Prompt 19（交付前自检）。

补进 18 的三条：

- 画布一个合并 `accessibilityLabel`，覆盖圆数、最大半径、旋转方向、首尾相接
- 步进按钮标注「降低一阶」「提高一阶」
- 平均偏离读数标注为「墨迹与原稿的平均偏离 5.0 点」

补进 19 的七条：

- [ ] 从 1100pt 拖到 700pt 再拖回，三档布局互切无残留、无崩版
- [ ] 三条锚点标注在三个预设 + 一个手绘形状下都不压住墨迹
- [ ] 按 ⊕ 时差量高亮四件事同时发生；按 ⊖ 与连续拖动**不**触发差量
- [ ] 差量高亮 900ms 后朱砂完全褪尽
- [ ] 步进反函数对 M ∈ [1, 256] 全域往返一致（贴 print）
- [ ] 平均偏离随 M 严格不回升，拖到 256 趋近 0（贴 print）
- [ ] 首轮字幕在任意一次触摸后立即消失，且存在期间不拦手势
