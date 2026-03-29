# 專案背景與架構指南 (Project Context & Architecture Guidelines)

## 1. 專案概述 (Project Overview)

本專案為使用 **Flutter** 開發的跨平台應用程式，後端服務 (BaaS) 採用 **Supabase**。這是一個「**課程/場地預約與營運管理系統**」（適用於健身房、補習班或預約制工作室）。系統具有明確的角色權限劃分，主要分為「**管理員後台 (Admin)**」與「**一般用戶/學生端 (Client)**」。

### 核心業務模組包含：
* **Auth (帳號與權限)**：登入註冊、權限分流。
* **Course & Booking (課程與預約)**：課程 (Course) 包含多個場次 (Session)，學生 (Student) 可進行預約 (Booking)。
* **HR & Payroll (人事與薪資)**：管理員工/教練 (Staff)、排班 (Work Shift) 以及薪資計算 (Salary/Payroll)。
* **Finance (財務收支)**：管理各項交易紀錄 (Transaction) 與退款/收入。
* **Resource (資源管理)**：場地或桌位管理 (Table Management)。

---

## 2. 系統架構 (Architecture)

專案採用「**層級與功能混合 (Layer-first mixed with Feature-based)**」的資料夾結構。遵守 Repository Pattern，UI 層不直接接觸資料庫，而是透過 Repository 溝通。路由管理預期使用 `GoRouter`。

### 目錄結構與職責說明 (`lib/`)

```text
lib/
├── core/             # 核心設定與工具
│   ├── constants/    # 系統常數 (例如: transaction_types.dart)
│   └── utils/        # 共用工具 (包含 logger, time_extensions, error handling 等 util.dart)
├── data/             # 資料層 (Models & Services)
│   ├── models/       # 資料模型 (純資料類別，負責與 Supabase 進行 JSON 序列化)
│   └── services/     # 封裝外部 API (Supabase Client) 與 CRUD 操作庫 (Repositories)
├── ui/               # 使用者介面層 (User Interface)
│   ├── admin/        # 管理員專用畫面 (依功能劃分: courses, dashboard, salary_management 等)
│   ├── screens/      # 一般用戶/共用畫面 (登入、首頁、預約紀錄等)
│   └── widgets/      # 全站共用 UI 元件 (跨 Admin 與 Screens)
├── main.dart         # 程式進入點 (初始化 GetIt 依賴注入與 Supabase 連線)
├── pbcopy            # (建議刪除: 通常為 macOS 終端機複製指令的殘留空檔案)
└── router.dart       # 統一定義 GoRouter 的路由與未登入重導向邏輯

```

### 資料層 (`data/`) 詳細檔案：

* **`models/`**: 包含 `booking_model.dart`, `course_model.dart`, `payroll_model.dart`, `session_model.dart`, `staff_detail_model.dart`, `student_model.dart`, `table_model.dart`, `transaction_model.dart`, `work_shift_model.dart` 等核心模型。
* **`services/`**: 包含 `auth_manager.dart` (管理全站登入狀態與路由守衛)，以及各模型的專屬 Repository (`auth_repository.dart` ~ `transaction_repository.dart`)。

### 介面層 (`ui/`) 詳細結構：

#### 📂 `admin/` - 管理員後台

* `admin_scaffold.dart`: 後台專用版面框架 (包含導覽列)。
* **`courses/`** (課程管理): 課程列表、詳情，及 `widgets/` 內的批次報名、編輯彈窗等。
* **`dashboard/`** (主控台): 後台首頁 (`dashboard_screen.dart`) 及每日行程表 (`daily_schedule_view.dart`)。
* **`salary_management/`** (薪資管理): 薪水管理、薪資分析圖表、員工列表及相關儀表板 Widget。
* **`students/`** (學員管理): 學員列表、詳情及相關小元件 (大頭貼、狀態標籤)。
* `table_management_screen.dart`: 場地或資源管理畫面。
* **`transactions/`** (財務與收支): 後台交易紀錄，包含桌面版表格、手機版列表與過濾條件 Widget。

#### 📂 `screens/` - 一般使用者/共用畫面

* `login_screen.dart` / `register_screen.dart`: 登入與註冊頁面。
* `homepage_screen.dart`: 客戶端首頁。
* `courses_screen.dart` / `course_detail_screen.dart`: 查看課程與報名畫面。
* `my_bookings_screen.dart` / `transaction_history_screen.dart`: 用戶預約紀錄與消費歷史。
* `notifications_screen.dart` / `notification_detail_screen.dart`: 系統通知中心。
* `profile_screen.dart`: 個人檔案設定。
* `scaffold_with_nav_bar.dart`: 客戶端主導覽框架。
* `splash_screen.dart`: App 啟動過場畫面。

---

## 3. 程式碼開發規範 (Coding Conventions & Rules)

> **⚠️ 致 AI 開發助手的嚴格指示：在生成或修改本專案的程式碼時，請務必遵守以下規範：**

### 3.1 錯誤處理機制 (Error Handling)

* **Repository 層 (`data/services/`)**：必須攔截錯誤**並向外拋出**。絕不可吞掉錯誤。
```dart
catch (e, stackTrace) {
  logError(e, stackTrace); // 記錄案發現場
  throw e;                 // 必須往外拋給 UI 層
}

```


* **UI 層 (`ui/`)**：必須捕捉錯誤並顯示給用戶。
```dart
catch (e) {
  logError(e); 
  if (mounted) {
    // 使用共用的彈窗工具顯示錯誤
    showErrorDialog(context, e.toString()); 
  }
}

```



### 3.2 狀態與變數宣告

* 控制 UI 狀態的變數（如控制密碼顯示隱藏的 `bool _obscurePassword`）**不可**設為 `final`。
* `StatefulWidget` 的 `State` 類別必須確實實作 `build` 方法。

### 3.3 依賴與 Import

* 統一使用 `package:ttmastiff/core/utils/util.dart` 來呼叫 `logError`，**禁止使用原生的 `print()**` 進行除錯。

### 3.4 UI 結構與拆分

* 盡量將複雜畫面拆分為小的 Widgets。若是特定模組專用的 Widget，請放在該功能資料夾下的 `widgets/` 目錄中（例如 `ui/admin/courses/widgets/`）；若是全站共用，則放在 `ui/widgets/` 中。
