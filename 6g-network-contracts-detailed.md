# مستندات تفصیلی تک‌تک قراردادهای هوشمند پروژه 6G-Network

**هدف این سند:** توضیح کامل نقش هر قرارداد، نحوه فعالیت آن در شبکه، و تشریح خط‌به‌خط ساختار کد (بر اساس کد واقعی تولیدشده توسط اسکریپت‌های `generateChaincodes_*.sh` و `gen-spatial-contracts.js`).

---

## بخش اول: دو الگوی ساختاری اصلی

همه ۸۶ قرارداد از یکی از دو الگوی زیر پیروی می‌کنند.

### الگوی الف — قراردادهای ثبت‌محور (۵۲ قرارداد غیرمکانی)

این قراردادها فقط **ثبت** می‌کنند. هیچ محاسبه رادیویی، پذیرش یا مدیریت منبعی انجام نمی‌دهند.

**ساختار استاندارد کد:**

```go
package main

import (
    "encoding/json"
    "fmt"
    "time"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ۱. تعریف نوع قرارداد (جاسازی Contract پایه)
type AuthenticateUser struct {
    contractapi.Contract
}

// ۲. ساختار داده رکورد (فیلدهای دامنه + Timestamp)
type UserAuth struct {
    UserID    string `json:"userID"`
    Token     string `json:"token"`
    Timestamp string `json:"timestamp"`
}

// ۳. Init — همیشه خالی (هیچ حالت اولیه‌ای ساخته نمی‌شود)
func (s *AuthenticateUser) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

// ۴. تابع اصلی نوشتن — ساخت ساختار + Marshal + PutState
func (s *AuthenticateUser) Authenticate(ctx contractapi.TransactionContextInterface, userID, token string) error {
    userAuth := UserAuth{
        UserID:    userID,
        Token:     token,
        Timestamp: txTimestamp(ctx),   // زمان قطعی از تراکنش (نه time.Now)
    }
    userAuthJSON, err := json.Marshal(userAuth)
    if err != nil {
        return err
    }
    return ctx.GetStub().PutState(userID, userAuthJSON)  // کلید = پارامتر اول
}

// ۵. QueryAsset — خواندن یک رکورد
func (s *AuthenticateUser) QueryAsset(ctx contractapi.TransactionContextInterface, userID string) (*UserAuth, error) {
    assetJSON, err := ctx.GetStub().GetState(userID)
    if err != nil {
        return nil, fmt.Errorf("failed to read from world state: %v", err)
    }
    if assetJSON == nil {
        return nil, fmt.Errorf("user authentication %s does not exist", userID)
    }
    var userAuth UserAuth
    err = json.Unmarshal(assetJSON, &userAuth)
    if err != nil {
        return nil, err
    }
    return &userAuth, nil
}

// ۶. QueryAllAssets — پیمایش کل فضای حالت
func (s *AuthenticateUser) QueryAllAssets(ctx contractapi.TransactionContextInterface) ([]*UserAuth, error) {
    resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
    // ... پیمایش و Unmarshal
}

// ۷. Validate* (در برخی قراردادها) — خواندن + مقایسه
func (s *AuthenticateUser) ValidateToken(ctx contractapi.TransactionContextInterface, userID, token string) (bool, error) {
    userAuth, err := s.QueryAsset(ctx, userID)
    if err != nil {
        return false, err
    }
    return userAuth.Token == token, nil
}

// ۸. txTimestamp — زمان قطعی از پیشنهاد تراکنش
func txTimestamp(ctx contractapi.TransactionContextInterface) string {
    ts, err := ctx.GetStub().GetTxTimestamp()
    if err != nil {
        return ""
    }
    return time.Unix(ts.Seconds, int64(ts.Nanos)).UTC().Format(time.RFC3339)
}

// ۹. main — راه‌اندازی chaincode
func main() {
    chaincode, err := contractapi.NewChaincode(&AuthenticateUser{})
    // ...
}
```

**نکات ساختاری مهم:**
- کلید دفتر همیشه پارامتر اول است.
- `txTimestamp` از `GetTxTimestamp` می‌آید تا روی همه peerها یکسان باشد.
- اکثر این قراردادها **نوشتن کور** هستند (بدون خواندن قبلی) → بدون تعارض MVCC در Tape.
- چند قرارداد تابع دوم دارند (`Disconnect`, `Update*`, `EndSession`) که معمولاً خواندن-تغییر-نوشتن‌اند.

---

### الگوی ب — قراردادهای مکانی (۳۴ قرارداد LocationBased*)

این قراردادها `NetworkBase` را جاسازی می‌کنند و منطق واقعی شبکه (انتخاب سلول سرویس‌دهنده، SINR، پذیرش، مدیریت طیف/انرژی، بازار) را اجرا می‌کنند.

**ساختار استاندارد:**

```go
package main

import (
    "encoding/json"
    "fmt"
    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ۱. جاسازی NetworkBase (شامل radio.go + مدیریت منابع + بازار)
type LocationBasedAssignment struct {
    NetworkBase
}

// ۲. ساختار رکورد دامنه + نتایج رادیویی محاسبه‌شده
type Assignment struct {
    EntityID      string `json:"entityID"`
    X             int64  `json:"x"`
    Y             int64  `json:"y"`
    ServingCell   string `json:"servingCell"`
    DistanceM     int64  `json:"distanceM"`
    RssiMilliDbm  int64  `json:"rssiMilliDbm"`
    SinrMilliDb   int64  `json:"sinrMilliDb"`
    CapacityBps   int64  `json:"capacityBps"`
    GrantedHz     int64  `json:"grantedHz"`
    TxTimeMicroS  int64  `json:"txTimeMicroS"`
    EnergyMicroJ  int64  `json:"energyMicroJ"`
    Timestamp     string `json:"timestamp"`
}

func (s *LocationBasedAssignment) Init(ctx contractapi.TransactionContextInterface) error {
    return nil
}

// ۳. تابع اصلی — فراخوانی admit + به‌روزرسانی سلول + نوشتن رکورد
func (s *LocationBasedAssignment) AssignAntenna(ctx contractapi.TransactionContextInterface, entityID, x, y, seed string) error {
    // اعتبارسنجی ورودی
    // بارگذاری ~CFG و بررسی بذر
    // فراخوانی s.admit(...) → انتخاب سلول، SINR، قیدها
    // در صورت TrackCapacity / TrackBandwidth / TrackEconomy: به‌روزرسانی رکورد آنتن
    // در صورت TrackEnergy: کاهش بودجه انرژی موجودیت
    // ساخت و PutState رکورد نهایی
}

// ۴. QueryAsset و QueryAllAssets (کلیدهای ~ را رد می‌کنند)
// ۵. ValidateCoverage / Validate* (بر اساس نتایج ذخیره‌شده)
// ۶. توابع مشترک از NetworkBase: SeedNetwork, Release, ServingCell, NetworkStatus, ...
```

**NetworkBase** شامل موارد زیر است (از `shared.go` / بلوک‌های تولیدشده):
- رجیستری آنتن (`~ANT:*`)
- پیکربندی شبکه (`~CFG`)
- تابع `admit` (انتخاب سلول + قیدهای پوشش/ظرفیت/طیف/انرژی)
- `SeedNetwork` / `PlaceOnGrid`
- مدیریت بودجه انرژی (`~NRG:`)
- بازار (حساب‌های راهراه، `ShareBandwidth`, `BuyQos`, `RelayFor`, ...)
- مدل رادیویی کامل از `radio.go`

---

## بخش دوم: تشریح تک‌تک قراردادها

قراردادها بر اساس کانال و نقش گروه‌بندی شده‌اند. برای هر گروه ساختار کد و نحوه فعالیت توضیح داده شده است.

### گروه ۱ — احراز هویت (authchannel)

#### AuthenticateUser
- **نقش:** ثبت توکن احراز هویت کاربر.
- **نحوه فعالیت:** فقط ثبت. هیچ اعتبارسنجی واقعی توکن انجام نمی‌شود.
- **ساختار کد:** الگوی الف. تابع `Authenticate(userID, token)` → PutState(userID). تابع `ValidateToken` برای مقایسه بعدی.

#### AuthenticateIoT
- مشابه AuthenticateUser ولی برای `deviceID`.

#### LocationBasedIoTAuthentication
- **نقش:** احراز هویت مکانی دستگاه IoT.
- **نحوه فعالیت:** علاوه بر ثبت توکن، موقعیت را ارزیابی می‌کند (admit) و سلول سرویس‌دهنده + SINR را ذخیره می‌کند.
- **ساختار:** الگوی ب. پارامترها: `deviceID, token, x, y, seed`.

#### VerifyIdentity
- **نقش:** ثبت وضعیت تأیید هویت (verified: bool).
- **نحوه فعالیت:** نوشتن کور با پارامتر غیررشته‌ای (bool). contractapi خودش `"true"`/`"false"` را تبدیل می‌کند.
- **ساختار:** الگوی الف با فیلد `Verified bool`.

---

### گروه ۲ — اتصال و رومینگ (connectivitychannel)

#### ConnectUser / ConnectIoT
- **نقش:** ثبت اتصال کاربر/دستگاه به یک آنتن مشخص.
- **نحوه فعالیت:** ثبت خالص + تابع دوم `Disconnect` که وضعیت را به "Disconnected" تغییر می‌دهد (خواندن-تغییر-نوشتن).
- **ساختار:** الگوی الف + تابع دوم.

#### LocationBasedConnection
- **نقش:** اتصال موجودیت به بهترین سلول بر اساس قدرت سیگنال.
- **نحوه فعالیت:** فراخوانی `admit` → انتخاب سلول → ثبت فاصله، RSSI، SINR، ظرفیت، انرژی.
- **ساختار:** الگوی ب. تابع اصلی `ConnectEntity(entityID, x, y, seed)`. قبلاً قفل بوت‌استرپ داشت (حالا با SeedNetwork باز شده).

#### LocationBasedRoaming
- مشابه Connection ولی برای ثبت جابه‌جایی بین سلول‌ها.
- تابع `PerformRoaming`.

#### LogConnectionAudit
- ثبت حسابرسی اتصال (الگوی الف).

---

### گروه ۳ — داده و سیگنال (datachannel)

#### LocationBasedAssignment
- **نقش:** تخصیص موجودیت به سلول سرویس‌دهنده (مهم‌ترین قرارداد مکانی).
- **نحوه فعالیت:**
  1. اعتبارسنجی entityID و مختصات
  2. بررسی بذر با `~CFG`
  3. `admit` → انتخاب قوی‌ترین سلول، محاسبه تداخل، SINR، شانون، زمان/انرژی
  4. قیدهای پوشش، ظرفیت، طیف، انرژی
  5. به‌روزرسانی `UsedCapacity` / `AllocatedHz` / `EarnedMicro` روی رکورد آنتن
  6. کاهش بودجه انرژی موجودیت (در صورت فعال بودن)
  7. PutState رکورد کامل Assignment
- **ساختار کد (خلاصه خط‌به‌خط تابع اصلی):**
  ```go
  // اعتبارسنجی
  if entityID == "" { return error }
  px, py := parseCoord(x), parseCoord(y)
  cfg := s.loadConfig(ctx)
  if seed != cfg.Seed { return mismatch }
  // پذیرش
  rep, best, err := s.admit(ctx, entityID, px, py)
  // به‌روزرسانی سلول (فقط اگر تغییری رخ داده)
  if trackCapacity { best.UsedCapacity++ }
  if trackBandwidth { best.AllocatedHz += rep.GrantedHz }
  if trackEconomy { best.EarnedMicro += cost }
  if cellChanged { s.saveAntenna(ctx, best) }
  // بودجه انرژی و کیف پول
  // ساخت رکورد نهایی و PutState
  ```

#### LocationBasedBandwidth
- مشابه Assignment ولی تمرکز روی تخصیص پهنای باند. تابع دوم `UpdateBandwidth` دارد.

#### LocationBasedSignalStrength / LocationBasedSignalQuality
- ثبت قدرت/کیفیت سیگنال محاسبه‌شده توسط مدل رادیویی.

---

### گروه ۴ — IoT (iotchannel و مرتبط)

#### LocationBasedIoTConnection / LocationBasedIoTBandwidth
- نسخه IoT از Connection و Bandwidth. قبلاً قفل بودند.

#### LocationBasedIoTStatus / LocationBasedIoTFault / LocationBasedIoTSession
- ثبت وضعیت، خرابی و نشست مکانی دستگاه.

#### ManageIoTDevice / MonitorIoT / LogIoTActivity
- ثبت‌محور (الگوی الف).

#### LocationBasedIoTRegistration / LocationBasedIoTRevocation
- ثبت‌نام و ابطال دسترسی مکانی (accesschannel).

#### LocationBasedIoTResource
- تخصیص منبع به دستگاه IoT با ارزیابی رادیویی.

---

### گروه ۵ — منابع (resourcechannel)

#### AllocateResource / LocationBasedResourceAllocation
- تخصیص منبع (طیف، پهنای باند و ...). نسخه مکانی از admit استفاده می‌کند.

#### LogResourceAudit / MonitorResourceUsage
- حسابرسی و پایش مصرف (ثبت خالص).

---

### گروه ۶ — کارایی و پایش

#### LocationBasedLatency (performancechannel)
- ثبت تأخیر محاسبه‌شده از مدل (زمان ارسال).

#### LogPerformance / LogNetworkPerformance / LogPerformanceAudit
- ثبت سنجه‌های کارایی (ثبت خالص).

#### LocationBasedStatus / Monitor* (monitoringchannel)
- وضعیت و پایش ترافیک/تداخل.

---

### گروه ۷ — مدیریت و بهینه‌سازی

#### LocationBasedAntennaConfig
- **نقش خاص:** عمل روی خود آنتن (جابه‌جایی موقعیت آنتن).
- **نحوه فعالیت:** موقعیت آنتن را در رجیستری به‌روز می‌کند و شعاع پوشش را با جستجوی دودویی روی منحنی افت مسیر محاسبه می‌کند.
- **نکته بنچمارک:** فقط ۸ کلید آنتن وجود دارد → تعارض MVCC بالا. باید با نرخ پایین سنجیده شود.

#### LocationBasedPowerManagement / LocationBasedChannelAllocation
- مدیریت توان و تخصیص کانال مکانی.

#### ManageAntenna / ManageNetwork / ManageUser
- تغییر وضعیت (ثبت خالص).

#### LocationBasedDynamicRouting / BalanceLoad / OptimizeNetwork
- ثبت تصمیم‌های مسیریابی و بهینه‌سازی (منطق واقعی اجرا نمی‌شود).

---

### گروه ۸ — سیاست، حسابرسی، امنیت، نشست، خرابی، ترافیک، دسترسی، انطباق، یکپارچه‌سازی

این گروه‌ها عمدتاً **ثبت خالص** هستند:

- **policychannel:** SetPolicy، UpdatePolicy (تنها قرارداد خواندن-تغییر-نوشتن واقعی)، GetPolicy (کد مرده — بدون تابع نوشتن)، LogPolicy*.
- **auditchannel:** مجموعه Log*Audit برای دسترسی، آنتن، انطباق، IoT، شبکه، امنیت، کاربر.
- **securitychannel:** EncryptData / DecryptData (فقط ثبت، رمزنگاری واقعی انجام نمی‌شود)، LogSecurityEvent.
- **sessionchannel:** ManageSession (Start/End)، LocationBasedSessionManagement، LogSession*.
- **faultchannel:** LocationBasedFault / LocationBasedIoTFault، LogFault.
- **trafficchannel:** LocationBasedTraffic / LocationBasedCongestion، LogTraffic.
- **accesschannel:** Register* / Revoke* / AssignRole / LogAccessControl + نسخه‌های مکانی.
- **compliancechannel:** LocationBasedPriority (با تابع UpdatePriority)، LogComplianceAudit.
- **integrationchannel:** LocationBasedInterference / LocationBasedUserActivity / LocationBasedSignalStrength (نسخه دوم)، Log*.

---

## بخش سوم: توابع مشترک NetworkBase (قراردادهای مکانی)

این توابع در همه ۳۴ قرارداد مکانی در دسترس هستند:

| تابع | نقش |
|------|-----|
| `SeedNetwork(seed, antennas, grid, capacity)` | چیدمان قطعی آنتن‌ها با PlaceOnGrid |
| `admit(...)` | انتخاب سلول + قیدهای پوشش/ظرفیت/طیف/انرژی |
| `Release(entityID)` | بازگرداندن ظرفیت و طیف |
| `ServingCell(entityID, x, y)` | پرس‌وجوی سلول سرویس‌دهنده بدون نوشتن |
| `NetworkStatus()` | گزارش وضعیت همه آنتن‌ها |
| `ShareBandwidth` / `BuyQos` / `RelayFor` | بازار |
| `BalanceOf` / `Mint` / `Transfer` | حساب‌های راهراه |
| `EnergyOf` | وضعیت بودجه انرژی |

---

## بخش چهارم: نکات ساختاری کلیدی برای همه قراردادها

1. **قطعیت:** همه محاسبات عدد صحیح هستند و `txTimestamp` از تراکنش می‌آید.
2. **فضای حالت مستقل:** هر chaincode فضای خودش را دارد → SeedNetwork باید برای هر جفت کانال-قرارداد جداگانه اجرا شود.
3. **کلیدهای مدل:** با پیشوند `~` شروع می‌شوند تا QueryAllAssets آن‌ها را رد کند.
4. **نوشتن کور در مقابل خواندن-تغییر-نوشتن:** فقط UpdatePolicy و چند تابع دوم (Disconnect/Update) خواندن قبلی دارند.
5. **پارامتر seed:** در همه قراردادهای مکانی اجباری است و باید با بذر SeedNetwork مطابقت داشته باشد.

---

**پایان مستندات تفصیلی قراردادها**

این سند بر اساس کد واقعی تولیدشده توسط اسکریپت‌های پروژه نوشته شده و می‌تواند به عنوان مرجع خط‌به‌خط برای تحلیل یا پایان‌نامه استفاده شود.

برای هر قرارداد خاص که نیاز به کد کامل‌تر یا توضیح عمیق‌تر دارید، بگویید تا بخش مربوطه را گسترش دهم.
