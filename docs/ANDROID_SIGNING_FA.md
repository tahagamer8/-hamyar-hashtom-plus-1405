# امضای پایدار APK فهمینو

برای نصب نسخه‌های جدید روی نسخهٔ قبلی، تمام نسخه‌های انتشار باید با **همان keystore** امضا شوند. فایل keystore و رمزهای آن را هرگز داخل مخزن Git قرار ندهید.

## راه‌اندازی یک‌باره با کمک والد یا سرپرست

1. روی رایانهٔ مورد اعتماد، یک keystore انتشار به نام `fahmino-release.jks` بسازید. رمزها و فایل را در جای امن و پشتیبان‌گیری‌شده نگه دارید.
2. فایل را به Base64 تبدیل کنید:
   - Linux/macOS: `base64 -w 0 fahmino-release.jks`
   - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("fahmino-release.jks"))`
3. در GitHub مخزن به **Settings → Secrets and variables → Actions → New repository secret** بروید و این چهار Secret را بسازید:
   - `FAHMINO_KEYSTORE_BASE64`: متن Base64 کامل فایل
   - `FAHMINO_KEYSTORE_PASSWORD`: رمز keystore
   - `FAHMINO_KEY_ALIAS`: نام alias
   - `FAHMINO_KEY_PASSWORD`: رمز کلید
4. مقادیر Secret را در چت، کد، Issue یا فایل مخزن منتشر نکنید.

## رفتار ساخت

- اجرای Pull Request یا شاخهٔ آزمایشی با debug key موقت فقط برای آزمایش CI ساخته می‌شود؛ این APK آزمایشی برای ارتقای نسخهٔ نصب‌شده نیست.
- اجرای روی شاخهٔ main نیازمند هر چهار Secret است و APK انتشار را با keystore ثابت امضا می‌کند. اجرای شاخهٔ آزمایشی و Pull Request از امضای موقت استفاده می‌کند.
- keystore را عوض نکنید و از آن چند نسخهٔ پشتیبان امن داشته باشید.

## دربارهٔ نسخه‌های قبلی

نسخه‌هایی که قبلاً در runnerهای موقت GitHub با debug keystore ساخته شده‌اند، ممکن است با کلیدهای متفاوت امضا شده باشند. در این صورت، اندروید اجازهٔ نصب نسخهٔ پایدار روی نسخهٔ قبلی را نمی‌دهد و ممکن است یک‌بار حذف نسخهٔ قدیمی لازم شود. حذف برنامه می‌تواند داده‌های محلی را پاک کند؛ پیش از آن از یادداشت‌ها و اطلاعات مهم پشتیبان بگیرید.
