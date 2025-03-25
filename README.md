# 🚀 اسکریپت بهینه‌ساز MTU

اسکریپتی برای **پیدا کردن بهترین مقدار MTU** (Maximum Transmission Unit) در اینترفیس شبکه.  
این ابزار **به‌طور خودکار** مقدارهای مختلف MTU را تست کرده و **بهینه‌ترین مقدار** را برای **کمترین پینگ، کمترین جتر و بدون از دست رفتن پکت‌ها** تنظیم می‌کند.

🔗 **مخزن GitHub:**  
[Arash-Ariaye/mtu-optimizer](https://github.com/Arash-Ariaye/mtu-optimizer)

---

## ✨ ویژگی‌ها
✔ **پیدا کردن بهینه‌ترین MTU** برای کاهش پینگ و افزایش پایداری شبکه  
✔ **تست سریع و موازی** برای کاهش زمان اجرای تست‌ها  
✔ **تنظیم خودکار مقدار MTU** روی اینترفیس شبکه  
✔ **قابلیت اجرای خودکار از طریق `crontab`**  
✔ **ذخیره تمام نتایج تست در فایل `mtu_test_results.txt`**  

---

## 📌 پیش‌نیازها
- سیستم‌عامل **Ubuntu** یا **Debian**
- **دسترسی به اینترنت** برای تست پینگ
- **دسترسی root (اجرا با `sudo`)**
- نصب بودن ابزارهای `ping` و `ip` (به‌صورت پیش‌فرض در اکثر توزیع‌ها وجود دارند)

---

## ⚙️ تنظیمات اولیه
قبل از اجرا، درون اسکریپت می‌توانی این مقادیر را تغییر بدهی:

```bash
INTERFACE="eth0"   # نام اینترفیس شبکه
TARGET_IP="8.8.8.8" # آدرس IP برای تست پینگ
PING_COUNT=10       # تعداد پکت‌های ارسالی در هر تست
```

---

## 🚀 روش‌های دانلود و نصب
### ۱. دانلود و اجرای مستقیم با `wget`
اگر `git` روی سرورت نصب نیست، می‌توانی اسکریپت را مستقیماً دانلود کنی:
```bash
wget https://raw.githubusercontent.com/Arash-Ariaye/mtu-optimizer/main/mtu_test.sh -O mtu_test.sh
chmod +x mtu_test.sh
sudo ./mtu_test.sh
```

### ۲. کلون کردن مخزن از GitHub
```bash
git clone https://github.com/Arash-Ariaye/mtu-optimizer.git
cd mtu-optimizer
chmod +x mtu_test.sh
sudo ./mtu_test.sh
```

---

## 📊 نمونه خروجی
```bash
🔍 شروع تست MTU برای IP 8.8.8.8 با ۱۰ پکت...
MTU 1475: میانگین پینگ=25.123 ms، از دست رفتن پکت‌ها=0%، جتر=1.234 ms
MTU 1474: میانگین پینگ=24.987 ms، از دست رفتن پکت‌ها=0%، جتر=0.987 ms
[...]

✅ بهترین مقدار MTU: 1474  
   🔹 میانگین پینگ: 24.987 میلی‌ثانیه  
   🔹 از دست رفتن پکت‌ها: 0%  
   🔹 جتر: 0.987 میلی‌ثانیه  

⚙ در حال تنظیم مقدار MTU 1474 روی اینترفیس `eth0`...  
✅ **MTU جدید با موفقیت اعمال شد!**  
📄 نتایج کامل در فایل `mtu_test_results.txt` ذخیره شدند.
```

---

## ⏳ اجرای خودکار با Crontab (هر ۵ دقیقه)
### ۱. انتقال اسکریپت به `/root`
```bash
sudo mv mtu_test.sh /root/mtu_test.sh
sudo chmod +x /root/mtu_test.sh
```
### ۲. افزودن به `crontab`
```bash
(crontab -l 2>/dev/null; echo "*/5 * * * * /bin/bash /root/mtu_test.sh >> /var/log/mtu_optimizer.log 2>&1") | crontab -
```
### ۳. بررسی کرون‌جاب
```bash
crontab -l
```
🔹 باید خط زیر را ببینی:
```
*/5 * * * * /bin/bash /root/mtu_test.sh >> /var/log/mtu_optimizer.log 2>&1
```
### ۴. مشاهده لاگ‌ها
```bash
sudo cat /var/log/mtu_optimizer.log
```

---

## ⏳ تغییر زمان‌بندی اجرای خودکار
می‌توانی اجرای خودکار را به **هر ۱۰ دقیقه** یا **هر ساعت** تغییر بدهی:

- **هر ۱۰ دقیقه:**
```bash
(crontab -l 2>/dev/null; echo "*/10 * * * * /bin/bash /root/mtu_test.sh >> /var/log/mtu_optimizer.log 2>&1") | crontab -
```
- **هر ساعت:**
```bash
(crontab -l 2>/dev/null; echo "0 * * * * /bin/bash /root/mtu_test.sh >> /var/log/mtu_optimizer.log 2>&1") | crontab -
```

### ❌ حذف اجرای خودکار
```bash
crontab -e
```
🔹 سپس خط مربوط به اجرای اسکریپت را پاک کن.

---

## 📂 فایل‌های موجود در پروژه
| نام فایل | توضیحات |
|----------|----------|
| `mtu_test.sh` | اسکریپت اصلی برای تست و تنظیم MTU |
| `mtu_test_results.txt` | ذخیره نتایج تست‌های قبلی |

---

## 🔧 اشکال‌یابی
🔹 **خطای "اینترفیس وجود ندارد"** → نام اینترفیس را در اسکریپت چک کن.  
🔹 **تنظیم MTU انجام نشد** → مطمئن شو که اسکریپت را با `sudo` اجرا می‌کنی.  
🔹 **خطا در تست پینگ** → اینترنت و IP موردنظر برای تست را بررسی کن.  

📄 **مشاهده نتایج ذخیره‌شده:**  
```bash
cat mtu_test_results.txt
```

---

## 📜 مجوز
این پروژه تحت **MIT License** منتشر شده است. جزئیات بیشتر در فایل `LICENSE`.

---

## 📬 ارتباط با من
🔹 **GitHub:** [Arash-Ariaye](https://github.com/Arash-Ariaye)  
🔹 **مخزن پروژه:** [mtu-optimizer](https://github.com/Arash-Ariaye/mtu-optimizer)
