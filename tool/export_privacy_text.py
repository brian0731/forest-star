"""Bundle the same readable privacy policy inside the offline Flutter app."""
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
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
text = '森星小隊 隱私權政策\n生效及最後更新：2026 年 11 月 3 日\nAndroid 套件名稱：com.foreststar.forest_star\niOS Bundle ID：com.foreststar.foreststar\n' + ''.join(parser.parts)
target = ROOT / 'assets/privacy-policy.txt'
target.write_text(text.strip() + '\n', encoding='utf-8')
print(f'Exported {target.name}: {len(text)} characters')
