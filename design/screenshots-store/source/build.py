# 홍보 스크린샷 만들기: python3 build.py → board.html, 이어서 node shoot.mjs
import os
H=os.path.dirname(os.path.abspath(__file__)); RAW='../../screenshots-raw/'
P={'m':('#F8DFD3','#FDF0E9','#F5EACB'),'n':('#F5EACB','#FCF6E3','#DDE8DC'),'r':('#DDE8DC','#EFF5EE','#E2DDEA'),'l':('#E2DDEA','#F2EFF6','#F8DFD3'),'d':('#2E2A38','#575164','#5A443C')}
def curve(w,h,c,t):
    p,f,n=P[t]; e=lambda k:f'M0 {h-c*1.2*0}L{w} {h-c*k}'
    path=lambda k:f'M0 0H{w}V{h-c*k:.0f}C{w*.78:.0f} {h-c*k*.70:.0f} {w*.54:.0f} {h} 0 {h}Z'
    return f'<svg class="bg" width="{w}" height="{h}"><rect width="{w}" height="{h}" fill="{n}"/><path d="{path(.45)}" fill="{f}"/><path d="{path(1)}" fill="{p}"/></svg>'
def shot(src,w,x,y,r,b,rot=0): return f'<div class="dev" style="left:{x}px;top:{y}px;border-radius:{r+b}px;padding:{b}px;transform:rotate({rot}deg)"><img src="{RAW}{src}" style="width:{w}px;border-radius:{r}px"></div>'
out=[]
def canvas(id,w,h,t,head,sub,body,fs,pad,top,c):
    ink='#F6ECE6' if t=='d' else '#40322F'; s2='#C6B6AE' if t=='d' else '#6B5B57'
    out.append(f'<section id="{id}" style="width:{w}px;height:{h}px">{curve(w,h,c,t)}<h1 style="left:{pad}px;top:{top}px;font-size:{fs}px;color:{ink}">{head}<small style="color:{s2};font-size:{fs*.36:.0f}px">{sub}</small></h1>{body}</section>')
def phone(id,t,head,sub,src): canvas(id,1320,2868,t,head,sub,shot('iPhone/'+src,1010,141,870,130,14),128,120,190,700)
phone('iPhone-1','n','오늘의 말씀이<br>찾아옵니다','아침을 여는 한 구절','ph-room-morning.png')
xs=[('ph-room-morning.png',110,730),('ph-room-noon.png',680,850),('ph-room-rest.png',110,1940),('ph-room-night.png',680,2060)]
canvas('iPhone-2',1320,2868,'l','하루 네 번,<br>사락','아침 · 한낮 · 쉼 · 밤',''.join(shot('iPhone/'+a,512,x,y,66,9) for a,x,y in xs),128,120,190,700)
phone('iPhone-3','r','하루 5분,<br>마가복음 한 권','25일이면 끝까지 읽어요','ph-read-morning.png')
phone('iPhone-4','l','마음에 머문 말씀을<br>품어 두세요','받은 때의 색이 책갈피가 됩니다','ph-keep-morning.png')
phone('iPhone-5','m','오늘도 한 장<br>넘어갑니다','감사 한 줄을 남겨 보세요','ph-done-rest.png')
phone('iPhone-6','d','하루를 덮는<br>밤의 말씀','어두운 화면에서도 편안하게','ph-room-dark.png')
def pad(id,t,head,sub,src,land=False):
    b=shot('iPad/'+src,1840 if land else 1560,98 if land else 238,960 if land else 800,44,14) 
    canvas(id,2064,2752,t,head,sub,b,150,170,200,620)
pad('iPad-1','n','오늘의 말씀이<br>찾아옵니다','하루 네 번, 시간의 색으로','pad-room-morning.png')
pad('iPad-2','r','펼치면,<br>한 권의 책','왼쪽에는 말씀, 오른쪽에는 오늘의 본문','padL-room-morning.png',True)
pad('iPad-3','l','하루 5분,<br>마가복음 한 권','25일이면 끝까지 읽어요','pad-read-morning.png')
pad('iPad-4','m','마음에 머문 말씀을<br>품어 두세요','넓은 화면에서 한 구절씩','padL-keep-morning.png',True)
def duo(id,t,head,sub,src): canvas(id,2853,2007,t,head,sub,shot('iPhone-Duo/'+src,1900,470,690,110,16),140,180,150,460)
duo('iPhone-Duo-1','n','펼치면, 한 권의 책','왼쪽에는 말씀, 오른쪽에는 오늘의 본문','duoO-room-morning.png')
duo('iPhone-Duo-2','m','하루를 덮는 밤의 말씀','하루 네 번, 시간의 색으로','duoO-room-night.png')
duo('iPhone-Duo-3','r','마음에 머문 말씀을 품어 두세요','목록과 한 구절을 나란히','duoO-keep-morning.png')
canvas('iPhone-Duo-4-접힘',1398,2034,'l','접으면, 한 구절','말씀과 버튼이 한 화면에',shot('iPhone-Duo/duoC-room-morning.png',980,195,560,96,14),110,120,150,460)
def watch(id,t,head,src): canvas(id,416,496,t,head,'',shot('Watch/'+src,268,64,150,58,10),36,30,34,110)
watch('Watch-1','n','손목 위의 한 구절','w-morning.png'); watch('Watch-2','r','잠시 숨을 골라요','w-noon.png'); watch('Watch-3','m','하루를 덮는 말씀','w-night.png')
css='''@font-face{font-family:GB;src:url(../../sarak-3/fonts/GowunBatang-Regular.ttf)}body{margin:0;width:2900px}section{position:relative;overflow:hidden;margin-bottom:40px}.bg{position:absolute;left:0;top:0}h1{position:absolute;margin:0;font:400 1em/1.36 GB;letter-spacing:-.035em;white-space:nowrap}h1 small{display:block;margin-top:.7em;letter-spacing:-.02em;font-family:"Apple SD Gothic Neo",sans-serif}.dev{position:absolute;background:#171413;box-shadow:0 30px 70px rgba(74,55,51,.20)}.dev img{display:block}section[id^=Watch] .dev{box-shadow:none}section[id^=Watch] small{display:none}'''
open(H+'/board.html','w').write(f'<!doctype html><html lang="ko"><meta charset="utf-8"><style>{css}</style><body>{"".join(out)}</body></html>')
