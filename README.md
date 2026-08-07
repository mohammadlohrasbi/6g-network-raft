# مستندات کامل پروژه 6G-Network
## شبکه Hyperledger Fabric برای شبیه‌سازی لایه ثبت و اجماع شبکه‌های سلولی 6G

**مخزن:** https://github.com/mohammadlohrasbi/6g-network  
**تاریخ تهیه مستندات:** اوت ۲۰۲۶  
**نسخه:** بر اساس وضعیت فعلی شاخه main (شامل مدل رادیویی قطعی، مدیریت منابع و بازار دادوستد)

---

## فهرست مطالب

1. [مقدمه و انگیزه](#۱-مقدمه-و-انگیزه)
2. [معماری کلی سامانه](#۲-معماری-کلی-سامانه)
3. [مدل رادیویی قطعی (radio.go)](#۳-مدل-رادیویی-قطعی-radiogo)
4. [مدیریت منابع (طیف، نرخ و انرژی)](#۴-مدیریت-منابع-طیف-نرخ-و-انرژی)
5. [بازار دادوستد منابع](#۵-بازار-دادوستد-منابع)
6. [اسکریپت SeedNetwork](#۶-اسکریپت-seednetwork)
7. [کانال‌ها و قراردادها (تشریح کامل)](#۷-کانال‌ها-و-قراردادها-تشریح-کامل)
8. [رابط کاربری، سرور و بنچمارک](#۸-رابط-کاربری-سرور-و-بنچمارک)
9. [استقرار و اجرا (خلاصه RUNBOOK)](#۹-استقرار-و-اجرا-خلاصه-runbook)
10. [یافته‌های روش‌شناختی و محدودیت‌ها](#۱۰-یافته‌های-روش‌شناختی-و-محدودیت‌ها)
11. [پیشنهاد آزمایش‌ها](#۱۱-پیشنهاد-آزمایش‌ها)
12. [مراجع و فایل‌های کلیدی](#۱۲-مراجع-و-فایل‌های-کلیدی)

---

## ۱. مقدمه و انگیزه

شبکه‌های 6G نیازمند قابلیت‌هایی فراتر از سرعت و تأخیر هستند: یکپارچگی حسگری، هوش مصنوعی فراگیر، اتصال همه‌چیز (IoE) و پشتیبانی از سناریوهای بسیار متراکم. در چنین محیطی، **توافق بین چندین اپراتور** بر سر رویدادهای شبکه (تخصیص منابع، اتصال، خرابی، حسابرسی و ...) حیاتی است.

این پروژه یک **لایه ثبت و اجماع توزیع‌شده** با Hyperledger Fabric پیاده‌سازی می‌کند:

- عملیات واقعی شبکه در تجهیزات رادیویی و هسته انجام می‌شود.
- دفتر فقط **ردپای غیرقابل‌انکار و مشترک** بین ۸ سازمان (آنتن‌های ماکروسل) می‌سازد.
- تمرکز بر **مکان‌محوری واقعی**، **مدیریت منابع فیزیکی** و **بازار نظیربه‌نظیر** است.

طراحی عمداً از اجرای منطق کسب‌وکار پیچیده در chaincode اجتناب می‌کند تا هزینه خالص مسیر تأیید–ترتیب‌دهی–کامیت قابل اندازه‌گیری باشد.

---

## ۲. معماری کلی سامانه

| مؤلفه | مقدار / توضیح |
|-------|----------------|
| سازمان‌های همتا | ۸ (Org1 تا Org8) — هر کدام نماینده یک آنتن ماکروسل |
| Orderer | ۱ |
| کانال‌ها | ۲۰ کانال تخصصی |
| قراردادهای هوشمند | ۸۶ (Go) |
| اهداف بنچمارک | ۹۰ (چند قرارداد روی بیش از یک کانال) |
| قراردادهای مکانی | ۳۴ (با مدل رادیویی + مدیریت منابع + بازار) |
| سیاست تأیید پیش‌فرض | `OR(org1MSP.member, ..., org8MSP.member)` — یک امضا کافی است |

### ساختار پوشه‌ها

```
6g-network/
├── chaincode/          # ۸۶ قرارداد Go تولیدشده
├── config/             # cryptogen, configtx, docker-compose
├── docs/               # مستندات داخلی (architecture, market, resource, ...)
├── public/             # رابط وب (test.html, styles, ...)
├── reference/          # radio.go (هسته رادیویی) و تحلیل‌گرها
├── scripts/            # network.sh, seed-network.sh, generate*, deploy*, ...
├── server/             # بک‌اند Node.js (bench, scenario, fabric gateway)
├── MANIFEST.md
├── RUNBOOK.md
└── install.sh
```

### الگوی مشترک همه قراردادها

```go
func (s *X) Init(ctx) error                          // خالی
func (s *X) <تابع اصلی>(ctx, id, ...) error          // PutState(id, json)
func (s *X) QueryAsset(ctx, id) (*T, error)          // GetState
func (s *X) QueryAllAssets(ctx) ([]*T, error)        // GetStateByRange
func (s *X) Validate...(ctx, id, max) (bool, error)  // در ۳۶ قرارداد
```

کلید دفتر تقریباً همیشه پارامتر اول تابع است. این یکنواختی امکان workload عمومی را فراهم می‌کند.

---

## ۳. مدل رادیویی قطعی (radio.go)

فایل: `reference/radio.go`

**چرا عدد صحیح؟**  
Fabric نتایج chaincode را بایت‌به‌بایت مقایسه می‌کند. توابع float64 (math.Log10, math.Pow, ...) روی معماری‌ها و نسخه‌های مختلف Go ممکن است تفاوت یک‌بیتی بدهند → `ENDORSEMENT_POLICY_FAILURE`.

**واحدها:**
- موقعیت / فاصله: متر (int64)
- توان / RSSI / SINR: milli-dB / mdBm (۱ dB = ۱۰۰۰)
- فرکانس: مگاهرتز
- پهنای باند: هرتز
- نمای افت مسیر: صدم (۳.۰ → ۳۰۰)
- توان خطی: Q16 با آفست ۱۵۰ dB

**توابع اصلی:**

| تابع | نقش |
|------|-----|
| `PlaceOnGrid(seed, id, sizeM)` | قرارگیری قطعی بر اساس بذر |
| `DistanceM` | فاصله اقلیدسی |
| `PathLossMilliDb` | مدل log-distance با لنگر فضای آزاد |
| `ShadowingMilliDb` | سایه‌فرسایی (Irwin-Hall + FNV + Murmur) |
| `RssiMilliDbm` | توان دریافتی پس از بهره، افت مسیر و fading |
| `SinrMilliDb` | جمع خطی تداخل + نویز → نسبت به dB |
| `ShannonBps` | ظرفیت شانون |
| `TransmitTimeMicroS` / `TransmitEnergyMicroJ` | زمان و انرژی ارسال |

دقت نسبت به مرجع float64: افت مسیر ±۰.۰۳ dB، SINR ±۰.۰۲ dB، ظرفیت ±۰.۱٪.

---

## ۴. مدیریت منابع (طیف، نرخ و انرژی)

منبع اصلی: `docs/resource-management.md`  
الهام‌گرفته از مقاله Zuo, Jin و Zhang (VTC2021-Fall).

### مسئله‌ای که حل شد

قبلاً قرارداد ظرفیت فیزیکی را حساب می‌کرد اما پارامتر `bandwidth` کاربر را بدون هیچ قیدی ذخیره می‌کرد. انرژی هم فقط ثبت می‌شد.  
**منابع ثبت می‌شدند، مدیریت نمی‌شدند.**

### ۴.۱ استخر طیف (Spectrum Pool)

هر آنتن:
```go
type Antenna struct {
    ...
    BandwidthHz  int64   // پیش‌فرض ۲۰ مگاهرتز
    AllocatedHz  int64   // مقدار تعهدشده
}
```

در `admit`:
```go
if cfg.TrackBandwidth && best.AllocatedHz+cfg.RequestHz > best.BandwidthHz {
    return error("cell has no spectrum left")
}
```
پس از پذیرش `AllocatedHz` افزایش می‌یابد. با ۱۰۰ kHz به ازای هر موجودیت، هر سلول ۲۰۰ موجودیت جا می‌دهد.

### ۴.۲ نرخ روی سهم (Rate on Share)

```go
rateBandwidth := best.BandwidthHz
if cfg.TrackBandwidth {
    rateBandwidth = cfg.RequestHz   // سهم این موجودیت
}
capacity := ShannonBps(rateBandwidth, sinr)
```

این تغییر برای محاسبه صحیح انرژی حیاتی است (`e = P · D / R`).

### ۴.۳ بودجه انرژی (Energy Budget)

کلید: `~NRG:<entityID>` (هر موجودیت کلید مستقل)

```go
type EnergyBudget struct {
    EntityID, TotalMicroJ, RemainingMicroJ, SpentMicroJ, TxCount int64
    Timestamp string
}
```

محاسبه:
- `t = PayloadBits × 10⁶ / capacityBps` (µs)
- `e = MicroWatt(TxPower) × t / 10⁶` (µJ)

قید: اگر `RemainingMicroJ < e` → رد با پیام مشخص.

باتری اولین بار با ۵ ژول (۵٬۰۰۰٬۰۰۰ µJ) ساخته می‌شود.

### مسیر کامل یک تراکنش مکانی

1. اعتبارسنجی ورودی  
2. بارگذاری `~CFG`  
3. بررسی بذر با چیدمان  
4. بارگذاری آنتن‌ها (`~ANT:*`)  
5. ارزیابی رادیویی (فاصله → افت مسیر → سایه‌فرسایی → RSSI → SINR → شانون → زمان → انرژی)  
6. قید پوشش (SINR ≥ آستانه)  
7. قید ظرفیت اتصال (اختیاری)  
8. قید طیف (اختیاری)  
9. قید انرژی (اختیاری)  
10. برداشت طیف (نوشتن رکورد سلول)  
11. برداشت انرژی (نوشتن رکورد موجودیت)  
12. نوشتن رکورد اصلی

**یافته همزمانی کلیدی:**  
- طیف روی ۸ کلید سلول → تعارض MVCC بالا  
- انرژی روی کلیدهای موجودیت → بدون تعارض

---

## ۵. بازار دادوستد منابع

منبع اصلی: `docs/market-guide.md` و بلوک `scripts/market-block.js`

### ایده مرکزی

> کاربر فقط می‌تواند چیزی را بفروشد که قرارداد خودش صادر کرده، سنجیده یا بتواند اثباتش را راستی‌آزمایی کند.

هیچ عدد خوداظهاری پذیرفته نمی‌شود.

### چه چیزی قابل معامله است؟

| منبع | فروشنده | مبنای راستی‌آزمایی |
|------|---------|---------------------|
| طیف | کاربر دارای مجوز | قرارداد `~GRANT:` صادر کرده |
| کیفیت سرویس (QoS) | اپراتور | قرارداد خودش اولویت را اعمال می‌کند |
| رله دستگاه‌به‌دستگاه | کاربر نزدیک سلول | سه مسیر از مدل انتشار محاسبه می‌شود |
| سرویس شبکه | اپراتور آنتن | قرارداد خودش مجوز و ارسال را انجام داده |

### پول و حساب‌ها

دو سامانه موازی:
- `TokenAccount` (`~WALLET:`) → پرداخت سرویس به اپراتور
- `Account` (`~ACC:<id>:<stripe>`) → بازار نظیربه‌نظیر

**Striping (تقسیم موجودی):** برای کاهش تعارض MVCC روی حساب‌های داغ.  
تعداد زیرکلیدها قابل تنظیم (۱، ۴، ۱۶، ۳۲ ...).  
اعتبار به زیرکلید مشتق‌شده از `TxID` می‌رود؛ بدهکاری از همان نقطه شروع و اولین زیرکلید کافی را برمی‌دارد.

### بازار اول: اجاره طیف

```go
ShareBandwidth(from, to, hz, priceMicro)
```

- چک `HeldHz - SubletHz ≥ hz`
- طیف فقط روی همان سلول قابل استفاده است
- قیمت در همان تراکنش پرداخت می‌شود

### بازار دوم: کیفیت سرویس

```go
BuyQos(entityID, tier)   // 0=best-effort, 1=standard, 2=premium
SellQos(entityID)
QosOf(entityID)
```

| سطح | سهم طیف | نرخ تقریبی میانگین |
|-----|---------|--------------------|
| ۰ (best-effort) | ۱۰۰ kHz | ۰.۲۲۸ Mbps |
| ۱ (standard) | ۲۰۰ kHz | ۰.۴۵۶ Mbps |
| ۲ (premium) | ۴۰۰ kHz | ۰.۹۱۳ Mbps |

اولویت واقعی است: در شبکه اشباع، کاربران premium زودتر ظرفیت را پر می‌کنند.

### بازار سوم: رله دستگاه‌به‌دستگاه

```go
RelayFor(dealID, edgeEntity, edgeX, edgeY, relayEntity, relayX, relayY)
```

قرارداد سه لینک را حساب می‌کند و بر اساس صرفه‌جویی خالص تصمیم می‌گیرد.  
رله هزینه خودش + سهمی از مازاد (پیش‌فرض ۵۰٪) را می‌گیرد.

قیدها: SINR بهتر رله، صرفه‌جویی مثبت، توان پرداخت، بودجه انرژی کافی.

### آنچه کنار گذاشته شد

- انتقال مستقیم انرژی بین باتری‌ها (فیزیکی بی‌معنا)
- پاداش Proof-of-Work (مناسب شبکه permissioned نیست)

---

## ۶. اسکریپت SeedNetwork

فایل: `scripts/seed-network.sh`

### چرا ضروری است؟

هر chaincode فضای حالت مستقل دارد. آنتن‌های یک قرارداد برای بقیه نامرئی‌اند. بنابراین باید چیدمان را **جداگانه** در هر قرارداد مکانی بنویسید → ۳۴ قرارداد + ۳ نسخه تکراری = **۳۷ فراخوانی**.

### پارامترها

| متغیر | پیش‌فرض | توضیح |
|-------|---------|-------|
| `SEED` | 42 | بذر شبه‌تصادفی (همان بذر → همان چیدمان) |
| `ANTENNAS` | 8 | تعداد آنتن‌ها |
| `GRID` | 10000 | اندازه شبکه (متر) |
| `CAPACITY` | (پیش‌فرض قرارداد) | ظرفیت هر سلول |
| `ONLY_CHANNEL` | — | فقط یک کانال |
| `VERIFY_ONLY=1` | — | فقط گزارش، بدون نوشتن |

### جفت‌های کانال-قرارداد (۳۷ مورد)

```
managementchannel:LocationBasedAntennaConfig
managementchannel:LocationBasedPowerManagement
managementchannel:LocationBasedChannelAllocation
datachannel:LocationBasedAssignment
datachannel:LocationBasedBandwidth
datachannel:LocationBasedSignalStrength
datachannel:LocationBasedSignalQuality
connectivitychannel:LocationBasedConnection
connectivitychannel:LocationBasedRoaming
iotchannel:LocationBasedIoTConnection
iotchannel:LocationBasedIoTBandwidth
iotchannel:LocationBasedIoTStatus
iotchannel:LocationBasedIoTFault
iotchannel:LocationBasedIoTSession
analyticschannel:LocationBasedQoS
analyticschannel:LocationBasedCoverage
analyticschannel:LocationBasedEnergy
networkchannel:LocationBasedNetworkLoad
networkchannel:LocationBasedNetworkHealth
resourcechannel:LocationBasedResourceAllocation
resourcechannel:LocationBasedIoTResource
performancechannel:LocationBasedLatency
authchannel:LocationBasedIoTAuthentication
sessionchannel:LocationBasedSessionManagement
sessionchannel:LocationBasedIoTSession
monitoringchannel:LocationBasedStatus
optimizationchannel:LocationBasedDynamicRouting
faultchannel:LocationBasedFault
faultchannel:LocationBasedIoTFault
trafficchannel:LocationBasedTraffic
trafficchannel:LocationBasedCongestion
accesschannel:LocationBasedIoTRegistration
accesschannel:LocationBasedIoTRevocation
compliancechannel:LocationBasedPriority
integrationchannel:LocationBasedInterference
integrationchannel:LocationBasedSignalStrength
integrationchannel:LocationBasedUserActivity
```

### نحوه اجرا

```bash
./seed-network.sh                          # پیش‌فرض
SEED=7 ./seed-network.sh                   # چیدمان متفاوت
ANTENNAS=16 GRID=20000 ./seed-network.sh
./seed-network.sh datachannel              # فقط یک کانال
VERIFY_ONLY=1 ./seed-network.sh            # فقط بررسی
```

بدون این اسکریپت، هر تراکنش مکانی با خطای «no antenna layout yet» رد می‌شود.  
بنچمارک‌ها باید دقیقاً همان `SEED` را استفاده کنند.

---

## ۷. کانال‌ها و قراردادها (تشریح کامل)

### ۷.۱ networkchannel — وضعیت و بار کل شبکه
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedNetworkLoad | RecordNetworkLoad | ✅ | بار لحظه‌ای در یک نقطه |
| LocationBasedNetworkHealth | RecordNetworkHealth | ✅ | سلامت شبکه در یک نقطه |
| ManageNetwork | UpdateNetworkStatus | ❌ | تغییر پیکربندی سطح شبکه |
| MonitorNetwork | RecordStatus | ❌ | سنجه پایش |

### ۷.۲ resourcechannel — تخصیص منابع رادیویی
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedResourceAllocation | AllocateResource | ✅ | تخصیص منبع به موجودیت |
| LocationBasedIoTResource | AllocateIoTResource | ✅ | تخصیص به دستگاه IoT |
| AllocateResource | Allocate | ❌ | تخصیص ساده |
| LogResourceAudit | LogResourceAudit | ❌ | حسابرسی |
| MonitorResourceUsage | RecordUsage | ❌ | مصرف جاری |

### ۷.۳ performancechannel — سنجه‌های کارایی
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedLatency | RecordLatency | ✅ | تأخیر مشاهده‌شده |
| LogPerformance | LogPerformance | ❌ | ثبت سنجه |
| LogNetworkPerformance | Log | ❌ | کارایی سطح شبکه |
| LogPerformanceAudit | Log | ❌ | حسابرسی کارایی |

### ۷.۴ iotchannel — چرخه عمر دستگاه IoT (پرجمعیت‌ترین)
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedIoTConnection | ConnectIoT | ✅ (قبلاً قفل) | اتصال به آنتن با فاصله واقعی |
| LocationBasedIoTBandwidth | AllocateIoTBandwidth | ✅ (قبلاً قفل) | تخصیص پهنای باند |
| LocationBasedIoTStatus | UpdateIoTStatus | ✅ | وضعیت جاری |
| LocationBasedIoTFault | ReportIoTFault | ✅ | گزارش خرابی |
| LocationBasedIoTSession | StartIoTSession | ✅ | شروع نشست |
| ManageIoTDevice | UpdateDeviceStatus | ❌ | مدیریت وضعیت |
| MonitorIoT | RecordStatus | ❌ | پایش |
| LogIoTActivity | Log | ❌ | ثبت فعالیت |

### ۷.۵ authchannel — احراز هویت
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedIoTAuthentication | AuthenticateIoT | ✅ | احراز هویت مکانی |
| AuthenticateIoT | Authenticate | ❌ | احراز هویت ساده IoT |
| AuthenticateUser | Authenticate | ❌ | احراز هویت کاربر |
| VerifyIdentity | Verify | ❌ | تأیید هویت (پارامتر bool) |

### ۷.۶ connectivitychannel — اتصال و رومینگ
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedConnection | ConnectEntity | ✅ (قبلاً قفل) | اتصال موجودیت به آنتن |
| LocationBasedRoaming | PerformRoaming | ✅ (قبلاً قفل) | رومینگ |
| ConnectIoT / ConnectUser | Connect | ❌ | اتصال ساده |
| LogConnectionAudit | Log | ❌ | حسابرسی |

### ۷.۷ sessionchannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedSessionManagement | ManageSession | ✅ | مدیریت نشست مکانی |
| LocationBasedIoTSession | StartIoTSession | ✅ | نشست IoT (نسخه دوم) |
| ManageSession | StartSession / EndSession | ❌ | نشست عمومی |
| LogSession / LogSessionAudit | Log... | ❌ | ثبت و حسابرسی |

### ۷.۸ policychannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| SetPolicy / UpdatePolicy / GetPolicy | ... | ❌ | مدیریت سیاست (GetPolicy کد مرده بود) |
| LogPolicyAudit / LogPolicyChange | Log... | ❌ | حسابرسی سیاست |

### ۷.۹ auditchannel
قراردادهای حسابرسی عمومی (LogAccessAudit، LogAntennaAudit، LogComplianceAudit، LogIoTAudit، LogNetworkAudit، LogSecurityAudit، LogUserAudit و ...). همه ثبت خالص.

### ۷.۱۰ securitychannel
| قرارداد | تابع اصلی | نقش |
|---------|-----------|-----|
| EncryptData / DecryptData | Encrypt / Decrypt | فقط ثبت (رمزنگاری واقعی انجام نمی‌شود) |
| LogSecurityEvent | Log | ثبت رویداد امنیتی |

### ۷.۱۱ datachannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedAssignment | AssignAntenna | ✅ (قبلاً قفل) | تخصیص به آنتن |
| LocationBasedBandwidth | AssignBandwidth | ✅ (قبلاً قفل) | تخصیص پهنای باند |
| LocationBasedSignalStrength | RecordSignalStrength | ✅ | قدرت سیگنال |
| LocationBasedSignalQuality | RecordSignalQuality | ✅ | کیفیت سیگنال |

### ۷.۱۲ analyticschannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedQoS | AssignQoS | ✅ (قبلاً قفل) | تخصیص کیفیت سرویس |
| LocationBasedCoverage | RecordCoverage | ✅ | پوشش |
| LocationBasedEnergy | RecordEnergy | ✅ | انرژی |

### ۷.۱۳ monitoringchannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedStatus | UpdateStatus | ✅ | وضعیت مکانی |
| MonitorInterference / MonitorTraffic | Record... | ❌ | پایش تداخل و ترافیک |

### ۷.۱۴ managementchannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedAntennaConfig | SetAntennaConfig | ✅ | پیکربندی آنتن |
| LocationBasedPowerManagement | SetPowerLevel | ✅ | مدیریت توان |
| LocationBasedChannelAllocation | AllocateChannel | ✅ | تخصیص کانال |
| ManageAntenna / ManageUser | Update... | ❌ | مدیریت وضعیت |

### ۷.۱۵ optimizationchannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedDynamicRouting | SetDynamicRoute | ✅ | مسیریابی پویا |
| BalanceLoad / OptimizeNetwork | Balance / Optimize | ❌ | توازن بار و بهینه‌سازی (فقط ثبت) |

### ۷.۱۶ faultchannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedFault | ReportFault | ✅ | گزارش خرابی |
| LocationBasedIoTFault | ReportIoTFault | ✅ | خرابی IoT (نسخه دوم) |
| LogFault | LogFault | ❌ | ثبت خرابی |

### ۷.۱۷ trafficchannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedTraffic | RecordTraffic | ✅ | ترافیک مکانی |
| LocationBasedCongestion | RecordCongestion | ✅ | ازدحام |
| LogTraffic | LogTraffic | ❌ | ثبت ترافیک |

### ۷.۱۸ accesschannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedIoTRegistration | RegisterIoT | ✅ | ثبت‌نام IoT |
| LocationBasedIoTRevocation | RevokeIoT | ✅ | ابطال دسترسی |
| RegisterIoT / AssignRole / LogAccessControl | ... | ❌ | ثبت‌نام و کنترل دسترسی |

### ۷.۱۹ compliancechannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedPriority | AssignPriority | ✅ | تخصیص اولویت |
| LogComplianceAudit | Log | ❌ | حسابرسی انطباق |

### ۷.۲۰ integrationchannel
| قرارداد | تابع اصلی | مکانی؟ | نقش |
|---------|-----------|--------|-----|
| LocationBasedInterference | RecordInterference | ✅ | تداخل |
| LocationBasedSignalStrength | RecordSignalStrength | ✅ | قدرت سیگنال (نسخه دوم) |
| LocationBasedUserActivity | RecordUserActivity | ✅ | فعالیت کاربر |
| LogInterference / LogUserActivity | Log... | ❌ | ثبت |

**نکته:** قبلاً ۷ قرارداد به خاطر قفل بوت‌استرپ آنتن مسدود بودند. با `SeedNetwork` همه رفع شده‌اند.

---

## ۸. رابط کاربری، سرور و بنچمارک

### سرور (Node.js)
- `bench-catalog.js` — تک‌منبع حقیقت: ۲۰ کانال + ۹۰ هدف
- `bench-runner.js` / `bench-routes.js` — اجرای پس‌زمینه و API
- `contract-fn-map.js` — نگاشت امضاها
- `scenario-core.js` — پشتیبانی از خواندن چیدمان از دفتر

### رابط وب
- صفحه Benchmark با پشتیبانی Tape و Caliper
- ماتریس پوشش
- پنج حالت انتخاب دامنه

### بنچمارک
- **Tape**: سقف ظرفیت (حداکثر tps). آرگومان‌ها ثابت است. تعارض MVCC را نمی‌بیند.
- **Caliper**: پروفایل تأخیر در نرخ ثابت. وضعیت نهایی تراکنش را می‌داند.

سیاست پیش‌فرض باید با استقرار (`OR`) هم‌تراز باشد (`fix-tape-policy.sh`).

---

## ۹. استقرار و اجرا (خلاصه RUNBOOK)

### پیش‌نیازها
- Ubuntu 24.04 (آزموده)
- حداقل ۴ گیگابایت RAM + swap، ۴۰+ گیگابایت دیسک
- Docker + Docker Compose v2، Go، Node.js، jq

### مسیر A — نصب تازه
1. کلون و نصب وابستگی‌ها
2. تولید ۸۶ قرارداد (`generateChaincodes_part*.sh` + spatial)
3. `./network.sh`
4. `./deploy-staged.sh` (ترجیحاً در tmux)
5. تست دودی
6. `./seed-network.sh` (**اجباری**)
7. همگام‌سازی نگاشت + restart داشبورد
8. نصب ابزارهای تست (Caliper + Tape)
9. امنیت (`secure-dashboard.sh` + `harden-docker-ports.sh`)

### مسیر B — ارتقای شبکه موجود
1. بازتولید قراردادهای مکانی
2. `./upgrade-spatial.sh`
3. بذرکاری + همگام‌سازی

جزئیات کامل در `RUNBOOK.md`.

---

## ۱۰. یافته‌های روش‌شناختی و محدودیت‌ها

### یافته‌ها
- تنها یک قرارداد (UpdatePolicy) خواندن-تغییر-نوشتن واقعی دارد → خطر MVCC در Tape.
- الگوی نوشتن طیف (کلیدهای مشترک) در برابر انرژی (کلیدهای موجودیت) تأثیر مستقیم روی گذردهی دارد.
- Striping حساب‌ها تعارض را به شدت کاهش می‌دهد ولی هزینه خواندن BalanceOf را افزایش می‌دهد.
- بسیاری از قراردادهای «LocationBased» قبلاً فقط فاصله تا مبدأ را حساب می‌کردند؛ حالا با مدل واقعی اصلاح شده‌اند.

### محدودیت‌ها
- قراردادها فقط ثبت می‌کنند، نه اجرا.
- فضای حالت مستقل chaincodeها → بدون یکپارچگی ارجاعی.
- صفحه Simulation هنوز ممکن است چیدمان متفاوتی نشان دهد (قابل رفع با خواندن NetworkStatus).
- نیاز به منابع سخت‌افزاری نسبتاً بالا برای ۲۰ کانال کامل.
- برخی کدهای مرده و اسکریپت‌های زائد هنوز در مخزن هستند.

---

## ۱۱. پیشنهاد آزمایش‌ها

1. **مقایسه خانواده مکانی vs ثبت خالص** — هزینه محاسبه درون‌قراردادی.
2. **تأثیر تعداد stripe روی گذردهی پرداخت به اپراتور**.
3. **اشباع طیف** — رفتار پذیرش/رد با افزایش موجودیت‌ها.
4. **تخلیه انرژی** — تکرار تراکنش با همان entityID.
5. **بازار رله** — صرفه‌جویی انرژی در برابر هزینه رله.
6. **تأثیر سیاست تأیید (OR vs majority)** روی اعداد Tape.
7. **مقیاس‌پذیری تعداد آنتن** (۸ → ۱۶ → ۳۲) با GRID بزرگ‌تر.

---

## ۱۲. مراجع و فایل‌های کلیدی

| فایل | نقش |
|------|-----|
| `docs/architecture-guide.md` | معماری قراردادها و کانال‌ها |
| `docs/network-roles.md` | نقش واقعی هر قرارداد |
| `docs/contract-inventory.md` | موجودی کامل ۸۶ قرارداد |
| `docs/resource-management.md` | مدیریت منابع |
| `docs/market-guide.md` | بازار دادوستد |
| `docs/benchmark-guide.md` | راهنمای Tape و Caliper |
| `reference/radio.go` | هسته رادیویی قطعی |
| `scripts/seed-network.sh` | بذرکاری آنتن‌ها |
| `scripts/market-block.js` | بلوک بازار تزریقی |
| `RUNBOOK.md` | دستورالعمل صفر تا صد |
| `MANIFEST.md` | فهرست بسته |

---

**پایان مستندات**

این سند بر اساس کد واقعی، مستندات داخلی مخزن و تحلیل دقیق تهیه شده است و می‌تواند به عنوان پایه گزارش فنی یا فصل‌های پایان‌نامه استفاده شود.

برای هر بخش خاص (کد یک قرارداد، نتایج بنچمارک، یا گسترش آزمایش‌ها) می‌توان مستندات تکمیلی تولید کرد.
