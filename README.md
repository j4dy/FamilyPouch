# 👛 FamilyPouch • Family Accounting & Receipt OCR

**FamilyPouch** is a role-aware Flutter Web application and mobile PWA designed for a 3-user household: **Mother**, **Father**, and **Helper**. It streamlines household budgeting with **automatic Receipt OCR**, helper grocery cash float tracking, out-of-pocket reimbursement claims with bank transfer proof, and weekly/monthly employer bill splitting.

---

## 🌟 Key Features

### 1. 👥 3-User Role-Based Architecture
- **👩 Mother & 👨 Father (Employers)**:
  - Record spending from **Joint Account** (shared direct fund) or **Out-of-Pocket** (to be claimed/split).
  - Disburse grocery petty cash float to Helper.
  - Review & settle out-of-pocket claims by uploading **Bank Transfer Proof Screenshots**.
  - Review weekly/monthly bill splitting statements and finalize settlement cycles.
- **🧑‍🍳 Helper (Employee)**:
  - Record spending from **Grocery Cash Float** or **Out-of-Pocket** (to be claimed).
  - Track available cash float balance in real-time.
  - Submit batch reimbursement claims for out-of-pocket expenses.

---

### 2. 🧾 Intelligent Receipt OCR & Manual Review (Human-in-the-Loop)
- **Instant Photo Extraction**: Take a photo or upload receipt files (JPG, PNG, PDF).
- **Auto-Extracted Entities**:
  - Store / Merchant name (e.g. Wellcome, PARKnSHOP, Watsons, CLP Power, Don Don Donki)
  - Total amount & candidate amount chips (e.g. Total vs Subtotal vs Discount)
  - Transaction date
  - Suggested category (Groceries, Utilities, Health & Medical, Dining, Kids, etc.)
  - Itemized line items list with prices & quantities
- **Interactive Review & Edit Screen**: Modify any field manually, adjust line items, or tap detected amount chips for instant correction.

---

### 3. 💵 Helper Grocery Cash Float Engine
- Initial balance + Cash-in Top-Ups from Joint Account - Cash spent = **Current Available Cash**.
- Complete ledger of disbursements and grocery receipts with receipt thumbnails and zoom lightbox.

---

### 4. 📑 Claims & Bank Transfer Proof Workflow
- Out-of-pocket expenses can be selected and submitted in claim batches.
- Employers settle claims with **mandatory Bank Transfer Screenshot Proof** and transaction reference numbers (FPS / PayMe / Bank transfer).

---

### 5. ⚖️ Weekly & Monthly Bill Splitting Engine
- Direct Joint Account expenses are shared equally (already funded).
- Equal 50/50 employer share:
  $$\text{Net Difference} = \frac{\text{Mother OOP} - \text{Father OOP}}{2}$$
- Displays exact settlement statement: e.g. *"Father transfers HK\$150.00 to Mother"*.
- Close and archive completed settlement cycles.

---

## 🚀 Getting Started

### Local Development
```bash
# 1. Clone repository
git clone https://github.com/j4dy/FamilyPouch.git
cd FamilyPouch

# 2. Install dependencies
flutter pub get

# 3. Run unit & widget tests
flutter test

# 4. Run web server locally
flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
```

---

## 🌐 Online Deployment to Firebase

### 1-Command Deploy:
```bash
# 1. Build release web app
flutter build web --release

# 2. Deploy to Firebase Hosting
npx -y firebase-tools deploy --only hosting
```

Your webapp will be immediately live on `https://<your-project-id>.web.app` with free SSL and global CDN edge caching!

---

## 📱 Mobile PWA Installation (Add to Home Screen)

Install on iPhones and Android phones without going through the App Store:
- **iPhone (Safari)**: Open website $\to$ Tap **Share** $\to$ Tap **"Add to Home Screen"**.
- **Android (Chrome)**: Open website $\to$ Tap **"Install App"** / **"Add to Home screen"**.
- The app will run in full-screen standalone mode with camera access for receipt capture!

---

## 🛠️ Architecture & Tech Stack
- **Framework**: Flutter Web 3.44+ (Dart 3.12+)
- **State Management**: Provider
- **Design System**: Material 3 Dark Theme with Slate/Indigo/Emerald glassmorphism
- **Persistence**: SharedPreferences / Browser LocalStorage
- **OCR Engine**: Pattern recognition and candidate entity extraction rules (`ReceiptParserRules` & `ReceiptOcrService`)
