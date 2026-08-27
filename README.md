# 📦 Mac 文件中转站 (MacFileRelay)

<p align="center">
  <b>极简 · 原生 · 无感 · 极速的 macOS 摇晃拖拽文件中转站</b><br>
  <i>Ultra-lightweight, native macOS shake-to-drop file shelf & relay station.</i><br><br>
  <a href="https://github.com/Yux-c/MacFileRelay/releases/latest">
    <img src="https://img.shields.io/github/v/release/Yux-c/MacFileRelay?color=blue&label=%E4%B8%8B%E8%BD%BD%E5%AE%89%E8%A3%85%E5%8C%85%20(DMG)&logo=apple" alt="Download DMG">
  </a>
</p>

---

## 🇨🇳 中文介绍 (Chinese)

**Mac 文件中转站 (MacFileRelay)** 是一款使用苹果原生 **Swift 6 + AppKit** 构建的极轻量文件中转与暂存小工具。

### 🌟 核心亮点

1. **🪅 摇晃鼠标，就地中转**：
   - 拖拽任意文件时，在屏幕任何位置**轻轻左右晃动两下光标**，毛玻璃中转站立刻在鼠标旁就地展开！
   - 原地暂存、原地释放，无需特意拖到屏幕边缘或顶部。
2. **📑 多文件连续暂存**：
   - 支持多次分批拖入任意数量的文件，横向流式列表，支持触摸板/滚轮自由滑动浏览。
3. **⏱️ 智能定时自动清理**：
   - 文件存入时自动开启倒计时（支持 1h / 12h / 24h / 3天 / 7天 / 仅手动），过期后**安全移入系统废纸篓**，绝不残留文件垃圾。
4. **📤 极速拖出到微信/邮件/访达**：
   - 鼠标按住卡片直接拖到聊天窗口、邮件或任意文件夹即可完成发送。
5. **👀 空格秒级预览 (QuickLook)**：
   - 悬停卡片按 `Space` 空格键或点击 `👁️` 眼睛图标，立即调出 macOS 原生 QuickLook 大图/音视频预览。
6. **⚡ 极致轻量与省电**：
   - 零网页套壳，纯原生编译，待命时 **0.0% CPU**，内存仅十几 MB。

### ⌨️ 快捷操作

| 动作 | 方式 | 说明 |
| :--- | :--- | :--- |
| **就地唤出 / 立即关闭** | 拖拽文件时**摇晃鼠标** | 晃一下打开，再晃一下立刻秒关 |
| **快捷打开 / 隐藏** | **`⌥ + D`** (Option + D) | 随时在鼠标位置召唤或收起中转站 |
| **空格快速预览** | **`Space`** (空格键) 或点击 **`👁️`** | 调出 macOS 原生 QuickLook 预览 |
| **按住直接拖出** | 按住任意卡片拖拽 | 直接拖出到微信、邮件或访达 |
| **偏好设置** | 点击右上角 **`⚙️`** 或按 **`⌘ + ,`** | 自定义语言、快捷键、灵敏度、自动清理周期等 |
| **菜单栏管理** | 点击顶部菜单栏 **`📥`** 小图标 | 快速管理中转站 |

---

## 🇺🇸 English (Overview)

**MacFileRelay** is an ultra-fast, native macOS utility designed to make moving and organizing files frictionless.

### 🌟 Key Features

- **Shake to Summon**: Simply shake your cursor while dragging files, and the relay shelf appears right next to your pointer.
- **Multi-File Shelf**: Drop multiple files at once or append over time with horizontal scrolling.
- **Auto-Cleanup Engine**: Automatically moves stale files to the macOS Trash after your chosen retention period (1h, 12h, 24h, 3d, 7d).
- **Native QuickLook**: Spacebar preview for images, audio, video, PDFs, and code.
- **Native & Featherlight**: Built in pure Swift 6 + AppKit. 0.0% idle CPU and minimal RAM footprint.

---

## 🛠️ 编译与安装 (Build & Install)

```bash
# 1. Clone repository
git clone https://github.com/Yux-c/MacFileRelay.git
cd MacFileRelay

# 2. One-click build and install
chmod +x build.sh
./build.sh
```

---

## 📄 开源协议 (License)

[MIT License](LICENSE) © 2026 MacFileRelay Authors.
