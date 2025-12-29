# 🏸 Court Manager (球館課程管理系# 🏸 Court Manager (球館課程管理系統)

這是一個基於 **Flutter** 與 **Supabase** 開發的跨平台球館管理系統。支援 iOS 與 Android 雙平台。
系統旨在解決球館的課程預覽、學員報名、現場 QR Code 簽到以及管理員的後台排課需求。

---

## 📖 目錄 (Table of Contents)

1. [關於專案 (About)](#-關於專案-about)
2. [技術架構 (Tech Stack)](#-技術架構-tech-stack)
3. [專案結構 (Project Structure)](#-專案結構-project-structure)
4. [快速開始 (Getting Started)](#-快速開始-getting-started)
5. [資料庫設計 (Database Schema)](#-資料庫設計-database-schema)
6. [開發規範 (Development Guideline)](#-開發規範-development-guideline)

---

## ℹ️ 關於專案 (About)

本專案分為兩個主要角色視角：
- **使用者端 (User)**: 瀏覽課程、管理報名紀錄、請假、個人資訊管理。
- **管理員端 (Admin)**: 開設課程、管理學員名單、現場掃碼簽到、權限管理。

## 🛠 技術架構 (Tech Stack)

| 類別 | 技術/套件 | 說明 |
| :--- | :--- | :--- |
| **Frontend** | Flutter (Dart) | 跨平台 App 開發框架 |
| **Backend** | Supabase | BaaS (PostgreSQL, Auth, Realtime) |
| **Routing** | go_router | 宣告式路由管理 |
| **Config** | flutter_dotenv | 環境變數與機密管理 |
| **Formatting** | intl | 日期與時間格式化 |
| **Fonts** | google_fonts | Google 字體整合 |

## 📂 專案結構 (Project Structure)

本專案採用 Feature-based 與 Layer-based 混合架構：

```text
lib/
├── core/                # 全域共用層 (Constants, Utils, Themes)
├── data/                # 資料層 (處理 API 與資料轉換)
│   ├── models/          # Data Models (Course, Profile, Booking)
│   └── services/        # Supabase Repository 邏輯
└── ui/                  # 表現層 (UI 邏輯)
    ├── screens/         # 完整的頁面 (Page)
    └── widgets/         # 可重用的元件 (Component)

## 🚀 快速開始 (Getting Started)
請依照以下步驟在本地端執行專案。

1. 環境需求
- Flutter SDK (最新版)
- VS Code 或 Android Studio
- Git

2. 安裝依賴
複製專案後，在終端機執行：

```Bash
flutter pub get
```

3. 設定環境變數 (Environment Variables) ⚠️ 重要
本專案使用 `.env` 檔案管理敏感資訊 (Supabase URL & Key)。 此檔案被列在 `.gitignore` 中，不會隨程式碼下載。

請在專案根目錄建立一個名為 `.env` 的檔案，並填入以下內容：

```
# .env
SUPABASE_URL=[https://你的專案ID.supabase.co](https://你的專案ID.supabase.co)
SUPABASE_ANON_KEY=你的SupabaseAnonKey
(請向專案管理員索取這些 Key，或至 Supabase Dashboard 查看)
```

4. 資料庫設定 (Database Setup)
若你是第一次建立此專案的後端，請參考專案目錄下的 `docs/db_schema.sql`，將其內容複製到 Supabase SQL Editor 執行，以建立必要的資料表。

5. 執行專案
確認模擬器已開啟：

```Bash
flutter run
```

## 🗄 資料庫設計 (Database Schema)
主要包含三張核心資料表：

1. profiles: 延伸 Auth 使用者資料，包含姓名、角色 (`admin/student`)。
2. courses: 課程資訊，包含時間、教練、最大名額。
3. bookings: 關聯表，紀錄學員報名狀態 (`confirmed`, `cancelled`) 與簽到時間 (`checked_in_at`)。

詳細欄位定義請參閱 `docs/db_schema.sql`。

## 📝 開發規範 (Development Guideline)
分支管理 (Branching):

- main: 穩定版本，隨時可部署。
- feature/功能名稱: 開發新功能使用 (例: feature/login-screen)。
- Commit 訊息: 請使用 Conventional Commits 格式。
- feat: 新功能
- fix: 修復 Bug
- docs: 修改文件
- style: 格式修改 (不影響程式邏輯)
- refactor: 重構
