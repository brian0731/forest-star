# iOS 審核：暫停轉珠

## 本版狀態

iOS 版暫停星願轉珠、免費及付費抽獎、錢包備份介面及內購初始化，不提供購買或轉珠入口。Android 維持原有流程。已解鎖角色及本機資料不會因本次修改被刻意清除；轉珠錢包及原本次數暫時不能在 iOS 使用，日後恢復前需先確認伺服器、已購交易及資料補領正常。

iOS 隱私頁使用本版本專用政策；公開網站不會因程式修改自動更新。商店頁、截圖、宣傳文字及線上告示板如仍顯示轉珠或購買，請在重新送審前修改為與本版一致。若以前曾實際向用戶銷售，應先確認消費者權益及既有購買處理，不應宣稱從未銷售。

## 重新送審

1. 使用包含本修改的新 iOS binary；先在實機及 iPad 模擬器檢查營地、夥伴頁、隱私頁及線上告示板。
2. 在 App Store Connect 選取新 build，移除本次不提供的內購項目及相關商店截圖／說明；檢查版本「App 內購買項目」是否仍包含未審核商品。
3. 核對 App Review Notes、年齡分級、App Privacy 及公開政策，按實際功能更新；若政策 URL 維持既有網址，需自行部署更新。
4. 在 App Review 回覆以下文字，並重新提交。是否需要提交商品或進一步資料，以 Apple 的回覆為準。

```text
Hello App Review,

Thank you for your feedback. In the new build, we have temporarily disabled the Star Wish Draw feature on iOS, including the purchase flow and wallet interface. The app no longer offers the associated in-app purchase or draw functionality in this version.

We have updated the app and its submission information to reflect this change. The core marble, companion and defense gameplay remains available without purchasing draw attempts.

Please review the new build. We plan to restore the feature only after the in-app purchase and associated server have been configured and tested.

Thank you.
```

以上回覆須待新 build 上傳、商店資料及公開政策實際更新後使用。勿聲稱已完成未核實的設定、測試或部署。

恢復轉珠時，依 [內購與伺服器設定](GACHA_IAP_SETUP.zh-TW.md) 建立商品、完成 Paid Apps Agreement、部署及設定交易核驗服務、準備 App Review 截圖，並用 Sandbox 測試購買、發放、斷線補領及退款後再向 Apple 提交。Apple 說明：[提交 App 內購買項目](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)；[設定審核沙盒](https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases/)。
