# 🧱 Ambigai Bricks Management System

A comprehensive, desktop-first ERP application built to digitize and streamline the daily operations of a brick manufacturing business. From inventory and production tracking to automated invoicing and dynamic financial analytics, this system provides end-to-end management for business owners and staff.

## 🚀 Key Features

* **Role-Based Access Control (RBAC):** Tailored dashboards and permissions for Business Owners, Office Managers, and Manufacturing Managers.
* **Order & Payment Tracking:** Complete order lifecycle management, including pending payments, partial payments, and due tracking.
* **Production & Inventory:** Real-time tracking of brick manufacturing, stock levels, and daily production metrics.
* **Delivery Challan (DC) Generation:** Seamlessly generate and manage Delivery Challans for shipments.
* **Advanced Financial Analytics:** Stock-market-style dynamic line and pie charts to visualize monthly sales revenues and expense trends.
* **Automated Reporting:** 1-click export of Invoices, Party Statements, and Expense summaries into **PDF** and **Excel** formats.
* **Windows Desktop Native:** Packaged as a lightweight, highly responsive `.exe` application for seamless desktop usage.

## 🛠️ Technology Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend & Database:** [Supabase](https://supabase.com/) (PostgreSQL)
* **Authentication:** Supabase Auth
* **State Management:** Provider
* **Charts & Analytics:** FL Chart
* **Windows Installer:** Inno Setup Compiler

## 📸 Screenshots

*(Add your screenshots here! Example formatting below)*
* `![Dashboard](link-to-dashboard-image.png)`
* `![Order Analytics](link-to-analytics-image.png)`
* `![PDF Generation](link-to-pdf-image.png)`

## ⚙️ Local Development Setup

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install)
2. Enable Windows Desktop support:
   ```bash
   flutter config --enable-windows-desktop
   ```
3. Set up a [Supabase](https://supabase.com/) project and retrieve your `URL` and `ANON_KEY`.

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/ambigai-bricks-app.git
   cd ambigai-bricks-app
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Environment Variables:**
   Create a `.env` file in the root directory (or configure via your IDE) and add your Supabase credentials:
   ```env
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **Run the App:**
   ```bash
   flutter run -d windows
   ```

## 📦 Building for Production (Windows .exe)

To build the release version of the Windows application:
```bash
flutter build windows
```
*(Optional)* To package it into a distributable setup file, you can use [Inno Setup](https://jrsoftware.org/isinfo.php) with the provided `.iss` script in the `/installer` directory.

## 🤝 Contributing

This project is a custom consultancy solution. However, feedback, bug reports, and suggestions are always welcome! Feel free to open an issue or submit a pull request.
