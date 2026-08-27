# 📦 Mac 文件中转站 (MacFileRelay)

<p align="center">
  <b>极简 · 原生 · 无感 · 0 误触的 macOS 摇晃拖拽文件中转站</b><br>
  <i>Ultra-lightweight, native macOS shake-to-drop file shelf & relay station.</i>
</p>

---

## 🇨🇳 中文介绍 (Chinese)

**Mac 文件中转站 (MacFileRelay)** 是一款使用苹果原生 **Swift 6 + AppKit** 构建的极轻量文件中转与暂存小工具。灵感源自 Dropover 与 Yoink，但剔除了所有冗余与侵入式设计。

### 🌟 核心亮点

1. **🪅 摇晃鼠标，就地中转**：
   - 拖拽任意文件时，在屏幕任何位置**轻轻左右晃动两下光标**，毛玻璃中转站立刻在鼠标旁就地展开！
   - 原地暂存、原地释放，无需拖到屏幕边缘或顶部。
2. **🛡️ 绝对 0 误触**：
   - 屏幕顶部与四周无任何常驻热区，**100% 避开系统调度中心（Mission Control）**与窗口标签栏冲突。
3. **📑 无限多文件批量暂存**：
   - 支持一次性框选或多次分批拖入任意数量的文件，横向流式列表，支持触摸板/滚轮自由滑动浏览。
4. **⏱️ 智能定时自动清理**：
   - 文件存入时自动开启倒计时（支持 1h / 12h / 24h / 3天 / 7天 / 仅手动），过期后**安全移入系统废纸篓**，绝不残留文件垃圾。
5. **📤 极速拖出到微信/邮件/访达**：
   - 按住卡片直接拖到聊天窗口、邮件或任意文件夹即可发送。
6. **👀 空格秒级预览 (QuickLook)**：
   - 悬停卡片按 `Space` 空格键或点击 `👁️` 眼睛图标，立即调出 macOS 原生 QuickLook 预览。
7. **🧰 一键 ZIP 打包**：
   - 点击右上角拉链图标，一秒将中转站内所有文件打包为 `.zip`。
8. **⚡ 极致轻量与省电**：
   - 零网页套壳，纯原生编译，待命时 **0.0% CPU**，内存仅十几 MB。

### ⌨️ 快捷操作

| 动作 | 方式 | 说明 |
| :--- | :--- | :--- |
| **就地唤出 / 立即关闭** | 拖拽文件时**摇晃鼠标** | 晃一下打开，再晃一下立刻秒关 |
| **快捷打开 / 隐藏** | **`⌥ + D`** (Option + D) | 随时在鼠标位置召唤或收起中转站 |
| **空格快速预览** | **`Space`** (空格键) 或点击 **`👁️`** | 调出 macOS 原生 QuickLook 预览 |
| **按住直接拖出** | 按住任意卡片拖拽 | 直接拖出到微信、邮件或访达 |
| **偏好设置** | 点击右上角 **`⚙️`** 或按 **`⌘ + ,`** | 自定义语言、快捷键、自动清理周期等 |
| **菜单栏管理** | 点击顶部菜单栏 **`📥`** 小图标 | 快速管理中转站 |

---

## 🇺🇸 English (Overview)

**MacFileRelay** is an ultra-fast, native macOS utility designed to make moving and organizing files frictionless. 

### 🌟 Key Features

- **Shake to Summon**: Simply shake your cursor while dragging files, and the relay shelf appears right next to your pointer.
- **Zero Mis-triggers**: No annoying notch or screen edge hotspots. Won't accidentally trigger Mission Control.
- **Multi-File Batch Shelf**: Drop multiple files at once or append over time with horizontal scrolling.
- **Auto-Cleanup Engine**: Automatically moves stale files to the macOS Trash after your chosen retention period (1h, 12h, 24h, 3d, 7d).
- **Native QuickLook**: Spacebar preview for images, audio, video, PDFs, and code.
- **Zip-All in One Click**: Archive all staged files into a single `.zip` file instantly.
- **Native & Featherlight**: Built in pure Swift 6 + AppKit. 0.0% idle CPU and minimal RAM.

---

## 🛠️ 编译与安装 (Build & Install)

```bash
# 1. Clone repository
git clone https://github.com/zyx2950129051-commits/MacFileRelay.git
cd MacFileRelay

# 2. One-click build and install
chmod +x build.sh
./build.sh
```

---

## 📄 开源协议 (License)

[MIT License](LICENSE) © 2026 MacFileRelay Authors.
