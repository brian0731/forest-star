"""Compose eight App Store screenshot graphics from actual Flutter captures."""

from pathlib import Path
import hashlib
import json
import random
import zipfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = ROOT / 'output/review/app-store-20261030'
DEST = ROOT.parents[1] / 'Builds/AppStore/Previews-20261030'
FONT = ROOT / 'assets/fonts/NotoSansTC.ttf'
PAGES = [
    dict(slug='01-camp', label='森林營地', title=['走進療癒森林', '展開小小冒險'],
         subtitle='彈珠・夥伴・守衛，從這裡出發',
         detail=['漫步在森林營地', '探索三個冒險地點', '和可愛夥伴一起出發'],
         color='#365c43', wash='#edf2df', art='camp', character=0),
    dict(slug='02-pinball', label='彈珠冒險', title=['輕輕一彈', '驚喜接連登場'],
         subtitle='彩色彈珠碰撞，為夥伴累積成長',
         detail=['瞄準，發射彩色彈珠', '碰撞累積成長分數', '落入六個夥伴籃'],
         color='#28596a', wash='#e5f1ed', art='camp', character=1),
    dict(slug='03-companions', label='夥伴養成', title=['六位可愛夥伴', '陪你一起長大'],
         subtitle='培育・升級・進化，組成你的隊伍',
         detail=['認識六位森林夥伴', '培育專屬戰鬥能力', '升級進化，閃耀登場'],
         color='#754a36', wash='#faecdc', art='companions', character=2),
    dict(slug='04-guard', label='四路守衛', title=['四路守衛出擊', '守住我們的營地'],
         subtitle='安排四位夥伴，迎戰森林裡的怪物',
         detail=['四條路線，橫向迎戰', '搭配不同夥伴能力', '一起守護森林營地'],
         color='#4b6040', wash='#edf0da', art='camp', character=3),
]


def font(size):
    face = ImageFont.truetype(str(FONT), size)
    face.set_variation_by_axes([700 if size >= 70 else 500])
    return face


def text(draw, xy, value, size, fill, anchor='lt', **kwargs):
    draw.text(xy, value, font=font(size), fill=fill, anchor=anchor, **kwargs)


def sparkle(draw, x, y, radius, fill):
    draw.polygon([(x, y-radius), (x+radius*.28, y-radius*.28),
                  (x+radius, y), (x+radius*.28, y+radius*.28),
                  (x, y+radius), (x-radius*.28, y+radius*.28),
                  (x-radius, y), (x-radius*.28, y-radius*.28)], fill=fill)


def background(size, page, seed):
    w, h = size
    art = Image.open(ROOT / f'assets/storybook/{page["art"]}.webp').convert('RGB')
    art = ImageOps.fit(art, size, method=Image.Resampling.LANCZOS)
    art = art.filter(ImageFilter.GaussianBlur(w/150))
    base = Image.new('RGB', size, page['wash'])
    # Existing game art supplies a subtle illustrated texture behind the UI.
    base = Image.blend(base, art, .14)
    paper = Image.new('RGB', size, '#fff9eb')
    veil = Image.new('L', (1, h))
    veil.putdata([int(225-90*y/h) for y in range(h)])
    base = Image.composite(paper, base, veil.resize(size))
    draw = ImageDraw.Draw(base)
    rng = random.Random(seed)
    for _ in range(24):
        x, y = rng.randrange(w), rng.randrange(h)
        r = rng.randint(3, 10)
        draw.ellipse((x-r, y-r, x+r, y+r), fill='#e7dcb5')
    for x, y, r in [(w*.08, h*.31, 16), (w*.92, h*.12, 25),
                    (w*.89, h*.86, 14), (w*.12, h*.92, 20)]:
        sparkle(draw, x, y, r, '#d7bb72')
    return base


def pill(draw, rect, label, size, fill, ink):
    draw.rounded_rectangle(rect, radius=(rect[3]-rect[1])/2, fill=fill)
    text(draw, ((rect[0]+rect[2])/2, (rect[1]+rect[3])/2), label, size, ink, 'mm')


def screenshot_card(canvas, path, box, radius):
    x, y, w, h = box
    shot = Image.open(path).convert('RGB')
    assert abs(shot.width/shot.height-w/h) < .002
    shot = shot.resize((w, h), Image.Resampling.LANCZOS)
    layer = Image.new('RGBA', canvas.size)
    shadow = Image.new('RGBA', canvas.size)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x-14, y+10, x+w+14, y+h+28), radius=radius+16, fill=(38, 57, 36, 65))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(25)))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((x-12, y-12, x+w+12, y+h+12),
                           radius=radius+12, fill='#fffcf3', outline='#d8c599', width=3)
    mask = Image.new('L', shot.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w-1, h-1), radius=radius, fill=255)
    layer.paste(shot, (x, y), mask)
    canvas.alpha_composite(layer)


def character(canvas, page, xy, side):
    path = ROOT / f'assets/storybook/character-{page["character"]}.png'
    art = Image.open(path).convert('RGBA')
    bbox = art.getchannel('A').getbbox()
    art = ImageOps.contain(art.crop(bbox), (side, side), Image.Resampling.LANCZOS)
    canvas.alpha_composite(art, (xy[0]+(side-art.width)//2, xy[1]+(side-art.height)//2))


def phone(page, index):
    size = (1179, 2556)
    canvas = background(size, page, index).convert('RGBA')
    draw = ImageDraw.Draw(canvas)
    pill(draw, (72, 70, 370, 138), '森星小隊', 34, page['color'], '#fff9eb')
    text(draw, (1105, 102), f'0{index} / 04', 30, page['color'], 'rm')
    for n, line in enumerate(page['title']):
        text(draw, (size[0]/2, 180+n*105), line, 88, page['color'], 'mt',
             stroke_width=1)
    text(draw, (size[0]/2, 409), page['subtitle'], 32, '#686954', 'mt')
    w = 908
    h = round(w*2556/1179)
    screenshot_card(canvas, CAPTURES/'iphone'/f'{page["slug"]}.png',
                    ((1179-w)//2, 502, w, h), 28)
    return canvas.convert('RGB')


def tablet(page, index):
    canvas = background((2732, 2048), page, index+20).convert('RGBA')
    draw = ImageDraw.Draw(canvas)
    pill(draw, (108, 86, 492, 170), '森星小隊', 44, page['color'], '#fff9eb')
    text(draw, (2605, 128), f'0{index} / 04', 37, page['color'], 'rm')
    headline = '，'.join(page['title'])
    text(draw, (108, 226), headline, 108, page['color'], stroke_width=1)
    text(draw, (112, 391), page['subtitle'], 44, '#686954')
    pill(draw, (108, 595, 555, 683), page['label'], 42, '#eee1bd', page['color'])
    for i, line in enumerate(page['detail']):
        sparkle(draw, 125, 786+i*100, 10, '#b49851')
        text(draw, (157, 786+i*100), line, 36, page['color'], 'lm')
    character(canvas, page, (132, 1120), 444)
    draw = ImageDraw.Draw(canvas)
    text(draw, (348, 1690), 'FOREST STAR', 31, '#847b59', 'mm')
    draw.line((158, 1760, 538, 1760), fill='#cfbd8a', width=2)
    text(draw, (348, 1818), '小小冒險・大大陪伴', 31, '#686954', 'mm')
    w = 1880
    h = round(w*2048/2732)
    screenshot_card(canvas, CAPTURES/'ipad'/f'{page["slug"]}.png',
                    (730, 556, w, h), 34)
    return canvas.convert('RGB')


def contact_sheet(device, paths):
    tw, th = (295, 639) if device == 'iphone' else (546, 410)
    sheet = Image.new('RGB', (4*tw+5*24, th+100), '#f4ecda')
    draw = ImageDraw.Draw(sheet)
    text(draw, (24, 14), f'森星小隊  /  {device.upper()}  /  4 SCREENSHOTS', 23, '#365c43')
    for i, path in enumerate(paths):
        img = Image.open(path).resize((tw, th), Image.Resampling.LANCZOS)
        sheet.paste(img, (24+i*(tw+24), 64))
    sheet.save(DEST/f'{device}-contact-sheet.jpg', quality=94)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    metadata = []
    for device, make, size in [('iphone', phone, (1179, 2556)),
                                ('ipad', tablet, (2732, 2048))]:
        folder = DEST/device
        folder.mkdir(exist_ok=True)
        paths = []
        for i, page in enumerate(PAGES, 1):
            output = folder/f'{device}-{page["slug"]}-{size[0]}x{size[1]}.png'
            image = make(page, i)
            assert image.size == size and image.mode == 'RGB'
            image.save(output, optimize=True)
            paths.append(output)
            metadata.append(dict(file=output.relative_to(DEST).as_posix(),
                                 width=size[0], height=size[1], mode='RGB',
                                 title='，'.join(page['title']),
                                 source=f'Flutter widget capture: {device}/{page["slug"]}.png',
                                 bytes=output.stat().st_size,
                                 sha256=hashlib.sha256(output.read_bytes()).hexdigest()))
        contact_sheet(device, paths)
    (DEST/'manifest.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2),
                                      encoding='utf-8')
    notes = '''# 森星小隊 App Store 截圖素材

製作日期：2026-10-30

- iphone/：4 張直向 PNG，每張 1179 × 2556 px。
- ipad/：4 張橫向 PNG，每張 2732 × 2048 px。
- 皆為 RGB、不含透明通道；順序為營地、彈珠、夥伴、守衛。
- 遊戲畫面來自目前 Flutter 程式實際渲染，外加商店標題及排版；沒有捏造額外遊戲 UI。擷取使用展示存檔與本機假廣告服務，不會請求或展示真正的廣告。
- 畫面由 Flutter 測試環境輸出，並非 iPhone / iPad 實機或 Xcode 模擬器截圖；公開送審前應與實機顯示核對。
- 此為靜態「截圖」素材。App Store Connect 的「App 預覽」欄用於影片，請把這些 PNG 放到截圖欄。
- 目前已上傳的 iOS build 13 只配置 iPhone；iPad 圖片為指定尺寸的素材，不代表已完成原生 iPad 支援。啟用 iPad、確認方向及版面後，再作對應上架用途。

尺寸參考：https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
'''
    (DEST/'使用說明.md').write_text(notes, encoding='utf-8')
    bundle = DEST/'forest-star-app-store-8-screenshots.zip'
    with zipfile.ZipFile(bundle, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for item in metadata:
            z.write(DEST/item['file'], item['file'])
        for name in ['manifest.json', '使用說明.md']:
            z.write(DEST/name, name)
    print(json.dumps(dict(output=str(DEST), images=metadata, zip=str(bundle)),
                     ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
