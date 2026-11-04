"""Keep the public HTML and offline policy aligned with the new purchase flow."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT.parents[1]/'Builds/GooglePlay/privacy-policy.html'
TARGET=ROOT/'server/updates/public/privacy-policy.html'
html=SOURCE.read_text(encoding='utf-8')
changes={
'本遊戲可離線遊玩，沒有註冊、登入、線上聊天或自建雲端存檔功能。我們不透過遊戲向您索取姓名、電郵、電話、地址或付款資料，也不將您的遊戲進度傳送至我們的伺服器。':
'核心遊戲及每日免費轉珠可離線使用，沒有電郵註冊、社群登入或線上聊天。付費星願轉珠使用匿名技術錢包、商店交易核驗及伺服器抽獎紀錄。我們不要求您在遊戲輸入姓名、電郵、電話、地址或付款卡資料；付款由 Apple App Store 或 Google Play 處理。關卡及一般遊玩進度不會上傳，付費錢包資料則依下節說明傳送。',
'<li><strong>偏好設定：</strong>':
'<li><strong>轉珠資料：</strong>免費額度日期及使用次數、獎品、各匿名錢包已套用的付費抽獎流水號；錢包 UUID、私人備份碼及待重試請求 ID 使用平台安全儲存。</li>\n          <li><strong>偏好設定：</strong>',
'        <h3>您主動聯絡我們時</h3>':
'''        <h3>星願轉珠與商店內購</h3>
        <p>在可使用官方內購的裝置上，App 會自動產生隨機錢包 UUID 與私人備份碼，並向 https://star.singtu.hk/api/gacha/ 傳送 UUID 及核對錢包所需的憑證。此識別碼只用於購買、核驗、發放次數及補領獎品，不提供給廣告服務。付款時 UUID 也會以 appAccountToken 或 obfuscatedExternalAccountId 提供給 Apple／Google，讓後端核對購買所屬錢包。</p>
        <p>購買及同步時，App 會向我們的伺服器傳送商品 ID、商店平台、交易 ID 或購買 token，以及尚未套用獎品的流水號。伺服器保存錢包 UUID、私人碼的雜湊、已驗證交易、必要 Google 購買 token、付費餘額、抽獎請求 ID、獎品與時間，用於防止同一筆交易重複發放、斷線補領及處理退款／撤銷。伺服器不保存私人備份碼原文或付款卡資料，也不接收您整份遊戲存檔。</p>
        <p>Apple／Google 依其隱私政策處理付款、帳單、商店帳戶及交易核驗；可分別參閱 <a href="https://www.apple.com/legal/privacy/" rel="noopener noreferrer">Apple 隱私權政策</a>及 <a href="https://policies.google.com/privacy?hl=zh-Hant" rel="noopener noreferrer">Google 隱私權政策</a>。付費次數及付費抽獎結果保存於我們部署的 Linux VPS，資料庫及備份只供必要營運人員管理；網路及主機供應商可能處理交付所需的 IP、連線及錯誤紀錄。免費轉珠結果僅存於裝置，不上傳。</p>
        <h3>您主動聯絡我們時</h3>''',
'1.10.0 起亦使用網路檢查及下載遊戲內容更新。':
'1.10.0 起亦使用網路檢查及下載遊戲內容更新；包含星願轉珠的新版本也使用網路連接官方商店、交易核驗及付費轉珠服務。',
'遊戲進度與設定會保留在裝置，直到您重設進度、清除應用程式資料或移除應用程式。您可以透過以下方式管理：':
'一般遊戲進度與設定保留在裝置，付費錢包及交易紀錄保存在伺服器。清除本機資料不等於刪除伺服器資料，也不會向商店申請退款。您可以透過以下方式管理：',
'<li><strong>重新開始遊戲：</strong>在營地點選「重設進度」，再於三秒內點選一次確認。請先結束正在進行的彈珠或守衛戰鬥；確認後，進度會恢復至初始狀態。</li>':
'<li><strong>備份付費錢包：</strong>在轉珠頁的鑰匙圖示複製私人備份碼。它可讓持有人控制該錢包，請私人保存；不要公開或寄到聯絡信箱。</li>',
'清除或重設後，我們無法從自己的伺服器為您恢復進度，因為我們沒有保存您的遊戲存檔。若裝置啟用系統備份，重新安裝時可能還原舊資料。':
'清除本機資料後，一般關卡及免費遊玩進度無法由我們的伺服器恢復。同一付費錢包的備份碼可用於取回未使用次數及重播已購轉珠獎品；沒有備份碼時，不能保證取回已消耗商品。Android 新版已停用一般 App 自動備份；iOS Keychain 及系統移轉可能另行保留資料，依平台設定而異。',
'「重設進度」只重設遊戲狀態，不會撤回廣告隱私選擇或刪除 Google 已持有的廣告資料。':
'新版營地的「重設進度」入口已改為星願轉珠。清除本機資料不會撤回 Google 已處理的廣告資料或刪除商店交易；',
'本遊戲沒有帳戶，因此無須申請帳戶刪除。若您曾透過電郵聯絡我們，可使用下方電郵要求查詢、更正或刪除您提供的聯絡資料；我們會在核實必要資訊後處理，依法必須保存的部分除外。聯絡紀錄僅在處理詢問與必要後續期間保留，完成後刪除或去識別化，依法須保留者除外。':
'如需查詢、更正或刪除匿名錢包相關資料，可使用下方電郵聯絡，提供錢包 UUID 或商店訂單參考資料，請勿提供私人備份碼、付款卡資料或 API 金鑰。我們會以必要方式核實請求；退款、財務稽核、防重複發放或依法必須保存的交易部分可能保留，其他不再必要的資料會刪除或去識別化。聯絡紀錄僅在處理詢問及必要後續期間保存。商店本身的訂單與帳單紀錄由 Apple／Google 依其政策管理。',
'本機遊戲資料存於 Android 或 iOS 管理的應用程式專屬儲存空間。我們不宣稱這些存檔另有獨立加密。':
'一般遊戲資料存於平台管理的 App 專屬儲存空間，未另行加密；錢包憑證使用平台安全儲存，連線使用 HTTPS，伺服器保存私人碼雜湊，交易資料庫需限制存取並備份。',
'家長或監護人如對兒童使用本遊戲或主動透過電郵提供的資料有疑問，或希望刪除相關聯絡資料，可與我們聯絡。':
'遊戲包含選擇性的付費隨機虛擬物品。每日免費轉珠不需付款，免費與付費機率相同並於購買前揭示。家長可使用 Apple／Google 的購買批准與家長控制功能限制購買。家長或監護人如對兒童使用本遊戲、匿名錢包或聯絡資料有疑問，或希望提出刪除請求，可與我們聯絡。',
}
if '星願轉珠與商店內購' not in html:
    for old,new in changes.items():
        if old not in html:raise RuntimeError(f'Missing expected policy text: {old[:40]}')
        html=html.replace(old,new)
html=html.replace('依您的 Android 版本、裝置廠商及備份設定，系統可能將應用程式的本機資料備份至 Google 或裝置廠商提供的服務，或移轉至另一部裝置。這些功能由作業系統與相關服務商提供；我們無法存取或管理您的系統備份。請在裝置的備份設定中管理，並參閱相關服務商的隱私權政策。',
    '包含星願轉珠的 Android 新版已停用一般 App 自動備份，以避免安全錢包資料在還原後無法解密。部分裝置移轉行為仍可能依作業系統及裝置廠商而異；我們無法存取或管理您的系統備份。請另外私人保存轉珠錢包備份碼。')
html=html.replace('傳送 UUID 及核對錢包所需的憑證。', '經 HTTPS 驗證標頭傳送 UUID 及私人碼，以核對錢包；伺服器只保存私人碼的雜湊。')
if '森林告示板透過系統 WebView' not in html:
    html=html.replace('        <h3>星願轉珠與商店內購</h3>', '        <p>森林告示板透過系統 WebView 載入 https://star.singtu.hk/notice.html，顯示網站 HTML、CSS、圖片及 JavaScript。網頁請求會向網站傳送 IP 位址、瀏覽器／系統資訊，並可能依網站內容使用 WebView 快取、Cookie 或本機網站儲存；App 不會向告示板注入遊戲存檔、錢包私人碼或商店付款憑證。離線公告文字可快取在裝置。</p>\n        <h3>星願轉珠與商店內購</h3>')
TARGET.write_text(html,encoding='utf-8')
SOURCE.write_text(html,encoding='utf-8')
print('Updated public and upload-ready privacy policy HTML')
