"""Bundle the same readable privacy policy inside the offline Flutter app."""
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'server/updates/public/privacy-policy.html'
if not SOURCE.exists():
    SOURCE = ROOT.parents[1] / 'Builds/GooglePlay/privacy-policy.html'

class PolicyText(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.in_article = False
        self.parts = []
    def handle_starttag(self, tag, attrs):
        if tag == 'article': self.in_article = True
        if self.in_article and tag in ('h2', 'h3', 'p', 'li', 'div'):
            self.parts.append('\n\n' + ('• ' if tag == 'li' else ''))
    def handle_endtag(self, tag):
        if tag == 'article': self.in_article = False
    def handle_data(self, data):
        if self.in_article and data.strip(): self.parts.append(data.strip())

parser = PolicyText()
parser.feed(SOURCE.read_text(encoding='utf-8'))
text = '森星小隊 隱私權政策\n生效及最後更新：2026 年 11 月 9 日\n' + ''.join(parser.parts)
text = text.replace('Google AdMob（Google Mobile Ads SDK）', 'AdMob 廣告 SDK')
text = text.replace('Google AdMob', 'AdMob')
text = text.replace('Google Cloud Text-to-Speech', '雲端文字轉語音服務')
text = text.replace('Google 使用者訊息平台', '使用者訊息平台')
text = text.replace('測試廣告亦可能連線至 Google。', '測試廣告亦可能連線至廣告服務商。')
text = text.replace('Google 或其廣告服務合作夥伴', 'AdMob 或其廣告服務合作夥伴')
text = text.replace('Google 隱私權政策', 'AdMob 服務商的隱私權政策')
text = text.replace('使用 Google 服務的網站與應用程式資料說明', '使用其服務的網站與應用程式資料說明')
text = text.replace('Google 已處理的廣告資料', '廣告服務商已處理的廣告資料')
text = text.replace('Google 保存的資料', '廣告服務商保存的資料')
text = text.replace('；Google 可能依 SDK', '；廣告服務商可能依 SDK')
target = ROOT / 'assets/privacy-policy.txt'
if any(value in text.lower() for value in ('android', 'google', 'bundle id', '套件名稱', 'com.foreststar')):
    raise SystemExit('Public policy includes platform-specific text. Adapt it for the shared app policy before updating the asset; existing asset was not changed.')
target.write_text(text.strip() + '\n', encoding='utf-8')
print(f'Exported {target.name}: {len(text)} characters')
