# BLA Connect - Project Context & Developer Guidelines

## 1. Project Overview

* **Project Name:** BLA Connect (School Management App)
* **Target Audience:** Parents, Teachers, Coordinators, Campus Heads, Admins (~2,000+ users)
* **Tech Stack:**
* **Frontend:** Flutter (SDK ^3.5.0, targeting Android 15/SDK 35), SQLite (`sqflite`) for local offline-first caching.
* **Backend:** PHP, MySQL (custom REST API endpoints).
* **Infrastructure:** AWS EC2 (8GB RAM), Firebase Cloud Messaging (FCM) for Push Notifications.



## 2. Architectural Guidelines & Best Practices

### Frontend (Flutter)

* **Offline-First & Syncing:** The app uses a local SQLite database to cache data. Syncing is done via the `syncEntity` function, which fetches data in batches (e.g., 1000 rows).
* **Batch Fetching Rule:** When paginating API results in `syncEntity`, strictly calculate loop termination based on the *current batch length*, not the total accumulated list length. Update SQL offsets incrementally by `batchSize`. Insert only the *current* batch into SQLite per iteration to prevent UI freezing.
* **State Management Separation:** Maintain strict separation between global app state (e.g., top-right header `_currentStudentId`) and local form state (e.g., `_selectedStudentId` in a dropdown).
* **Storage Desync Fallback:** If `flutter_secure_storage` drops credentials but SQLite persists, gracefully close the database (`await _sqLiteDB?.close()`), delete the DB file, and force a fresh login to prevent lockout states.
* **Text Field Autofill:** To prevent mobile OS password managers from hijacking multiline text fields (e.g., inserting phone numbers into correspondence messages), explicitly define `autofillHints: const [AutofillHints.name]` (or similar) and `keyboardType`.

### Backend (PHP/MySQL)

* **Query Optimization:** **Never use multiple `OR` conditions inside `JOIN` clauses.** This causes full table scans and crashes server performance (e.g., 12-second execution times). Always use `UNION` to merge separate, highly optimized indexed queries. `UNION` naturally deduplicates results.
* **Deployment & Server Load:** To prevent "Thundering Herd" server crashes on the EC2 instance, mandate staggered rollouts (e.g., Batch 1: Nursery/KG, Batch 2: Primary) for global announcements requiring data syncs.
* **Push Notifications (FCM):** FCM topics are dynamically created upon the first device subscription; they do not need pre-creation. FCM API will return a success (`200 OK`) even if zero devices are subscribed.

## 3. Known Quirks & Historical Fixes

### Android 15 (SDK 35) 16 KB Page Size Issue

Google Play strictly enforces 16 KB memory page size alignment for native C++ libraries (e.g., SQLite binaries). To bypass this without risking mass dependency upgrades:

* `android/gradle.properties`: Add `android.bundle.enableUncompressedNativeLibs=false`
* `android/app/src/main/AndroidManifest.xml`: Add `android:extractNativeLibs="true"` to the `<application>` tag.

### SQLite Relational Mapping (Contacts)

For mapping tables where one entity maps to multiple children (e.g., a teacher or admin linked to multiple `studentId`s), **do not use `id` as a solitary `PRIMARY KEY**` in SQLite. This will cause silent overwrite deletions during data sync. Use a composite unique constraint (e.g., `UNIQUE(id, classId, studentId)`) or remove the primary key entirely if the table is truncated before syncing.

### EC2 Storage Management

The `/var/log/php-fpm/` directory is prone to infinite expansion. Ensure `/etc/logrotate.d/php-fpm` is configured for daily rotation, capped at `50M`, keeping a max of 3 compressed archives, with a `postrotate` script to send `-SIGUSR1` to the PHP-FPM process.

### Ghost Inserts & Debugging

If rogue data (e.g., passwords/usernames) appears in tables like `app_correspondence_messages` or `app_diary_comments` due to OS autofill glitches, use MySQL triggers (`BEFORE INSERT`) connected to an `error_log` table to trap the exact payloads and sender IDs. For full stack tracing, inject `debug_backtrace()` logs into the PHP `BasicDataModel` execution layer.
