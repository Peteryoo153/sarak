import json,os,html
H=os.path.dirname(os.path.abspath(__file__)); R=os.path.dirname(H)
T=json.load(open(H+'/tokens.json')); HR=T['hour']; order=['morning','noon','rest','night']
def nxt(h): return order[(order.index(h)+1)%4]
def lum(c):
    v=[int(c[i:i+2],16)/255 for i in(1,3,5)]; v=[x/12.92 if x<=.03928 else((x+.055)/1.055)**2.4 for x in v]
    return .2126*v[0]+.7152*v[1]+.0722*v[2]
def cr(a,b):
    a,b=sorted((lum(a),lum(b)),reverse=True); return (a+.05)/(b+.05)
bad=[];rows=[]
for m in('light','dark'):
    assert cr(T['color'][m]['control'],T['color'][m]['canvas'])>=3,(m,'control')
for h in HR.values(): assert cr(h['light']['page'],'#000000')>=4.5
for m in('light','dark'):
    C=T['color'][m]
    P=[(C['ink'],C['canvas'],'글자/바탕'),(C['sub'],C['canvas'],'보조/바탕'),(C['onPrimary'],C['primary'],'버튼 글자'),(C['danger'],C['canvas'],'경고')]
    P+=[(C[k],HR[h][m]['page'],f"{n}/{HR[h]['name']}") for h in order for k,n in(('ink','글자'),('sub','보조'))]
    for a,b,n in P:
        x=cr(a,b); rows.append((m,n,x)); 
        if x<4.5: bad.append((m,n,round(x,2)))
assert not bad,bad
def v(h,m): 
    C=T['color'][m]; s=';'.join(f'--{k}:{x}' for k,x in C.items())
    return s+f";--page:{HR[h][m]['page']};--flap:{HR[h][m]['flap']};--next:{HR[nxt(h)][m]['page']}"
def curl(w,h,c=84,r=0,fill='var(--page)'):
    # 종이 아래 가장자리가 오른쪽으로 부드럽게 들리고, 종이 뒷면과 다음 시간의 색이 비친다
    sp=min(w,6*c); x=w-sp
    e=f'C{w-.22*sp:.1f} {h-.70*c:.1f} {w-.46*sp:.1f} {h} {x:.1f} {h}'
    pg=f'M0 0H{w}V{h-c:.1f}{e}H0Z'
    fl=f'M{w} {h-c:.1f}{e}H{x+.1*sp:.1f}C{w-.40*sp:.1f} {h} {w-.18*sp:.1f} {h-.24*c:.1f} {w} {h-.42*c:.1f}Z'
    return f'<svg class="pg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" aria-hidden="true"><rect x="{x:.1f}" y="{h-c:.1f}" width="{sp:.1f}" height="{c:.1f}" fill="var(--next)"/><path d="{fl}" fill="var(--flap)" class="flap"/><path d="{pg}" fill="{fill}" class="flap"/></svg>'
IC={'room':'M6 20V5a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v15M3.5 20h17M14.5 12v.6','book':'M12 6.5C10 5 7 4.6 3.5 5v13c3.500-.4 6.500 0 8.500 1.500 2-1.500 5-1.900 8.500-1.500V5C17 4.600 14 5 12 6.500Zm0 0V19','mark':'M7 4h10a1 1 0 0 1 1 1v15l-6-4.500L6 20V5a1 1 0 0 1 1-1Z','gear':'M4 8h9M17 8h3M4 16h3M11 16h9M15 5.800v4.400M9 13.800v4.400','back':'M15 5l-7 7 7 7','go':'M9 5l7 7-7 7','ear':'M5 14v-2a7 7 0 0 1 14 0v2M5 14h2.500v5H6a1 1 0 0 1-1-1v-4Zm14 0h-2.500v5H18a1 1 0 0 0 1-1v-4Z','copy':'M9 9h10v10H9zM15 9V5H5v10h4','pen':'M5 19l1-4L16 5l3 3L9 18l-4 1Z','search':'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm5 12 4 4','x':'M6 6l12 12M18 6 6 18','prev':'M18 6v12L9 12ZM6 6v12','nextv':'M6 6v12l9-6ZM18 6v12','pause':'M9 6v12M15 6v12','people':'M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm-6 8a6 6 0 0 1 12 0M16 5.500a3 3 0 0 1 0 5M18 14.500a6 6 0 0 1 3 4.500','play':'M8 5.500v13l10-6.500Z'}
def ic(n,s=24): return f'<svg class="ic" width="{s}" height="{s}" viewBox="0 0 24 24" aria-hidden="true"><path d="{IC[n]}"/></svg>'
def vs(t,src,size=32,lh=None): return f'<p class="verse" style="font-size:{size}px;line-height:{lh or round(size*1.5)}px">{t}</p><p class="src">{src}</p>'
def status(t): return f'<div class="st"><b>{t}</b><i></i></div>'
def tabs(sel=0):
    L=[('room','골방'),('book','성경'),('mark','말씀첩')]
    return '<nav class="tabs">'+''.join(f'<span class="{"on" if i==sel else ""}">{ic(a,22)}<small>{b}</small></span>' for i,(a,b) in enumerate(L))+'</nav>'
def btn(t,cls=''): return f'<span class="btn {cls}">{t}</span>'
def dev(w,h,body,cap,note='',hour='morning',mode='light',kind='phone',id=''):
    return f'<figure style="width:{w+(20 if kind!="watch" else 28)}px"><div class="dev {kind}" ><div class="scr" id="{id}" style="width:{w}px;height:{h}px;{v(hour,mode)}">{body}</div></div><figcaption><b>{cap}</b>{note}</figcaption></figure>'
V={'morning':('겨자씨<br>한 알과 같으니','마가복음 4:31','좋은 아침이에요','7:02'),'noon':('심긴 후에는 자라서<br>모든 풀보다 커지며','마가복음 4:32','잠시 숨을 골라요','12:24'),'rest':('안심하라 내니<br>두려워하지 말라','마가복음 6:50','쉬어 가도 괜찮아요','4:03'),'night':('잠잠하라<br>고요하라 하시니<br>바람이 그치고<br>아주 잔잔하여지더라','마가복음 4:39','오늘 하루, 수고했어요','9:31')}
BTN='오늘의 본문 5분쯤 읽기'; SUB='하루 5분, 25일이면 마가복음 한 권.'
def home(w,h,hour,ph,c=92,sz=36,tab=True,st=True,pad=28):
    a,b,g,t=V[hour]
    return f'{curl(w,ph,c)}{status(t) if st else ""}<div class="top" style="top:{62 if st else 22}px;left:{pad}px;right:{pad-10}px"><div><span class="cap">11월 24일 화요일</span><p class="hi">{g}</p></div><span><span class="tap">{ic("people")}</span><span class="tap">{ic("gear")}</span></span></div><div class="vb" style="left:{pad}px;right:{pad}px;bottom:{h-ph+56:.0f}px">{vs(a,b,sz)}</div><div class="low" style="top:{ph+24}px;left:24px;right:24px">{btn(BTN)}<p class="cap ctr">{SUB}</p></div>{tabs(0) if tab else ""}'
import sqlite3
db=sqlite3.connect('file:'+os.path.join(R,'../../ios-native/Sarak/Resources/bible.db')+'?mode=ro',uri=True)
def bib(a,b,sel=(),ch=4):
    o=''
    for n,t in db.execute('select verse,text from verses where book_id=41 and chapter=? and verse between ? and ?',(ch,a,b)):
        t=html.escape(t.strip()); o+=f'<sup>{n}</sup>'+(f'<mark>{t}</mark>' if n in sel else t)+' '
    return o
def readbar(t='마가복음 4:30–5:20'): return f'<div class="bar"><span class="tap">{ic("back")}</span><b>{t}</b><span class="tap"><em>가</em></span><span class="tap">{ic("ear")}</span></div>'
ACT=f'<div class="acts"><span>{ic("mark",20)}품기</span><span>{ic("copy",20)}복사</span><span>{ic("pen",20)}한 줄 남기기</span></div>'
def row(a,b='',r='',chip=''): return f'<div class="row">{chip}<div><p>{a}</p>{f"<small>{b}</small>" if b else ""}</div><span class="r">{r}</span></div>'
def tog(on=True): return f'<i class="tog {"on" if on else ""}"></i>'
def chip(h,m='light'): return f'<i class="chip" style="background:{HR[h][m]["page"]}"></i>'
def titled(t,body,tab=None,time='7:10',back=False): return status(time)+(f'<div class="bar"><span class="tap">{ic("back")}</span></div>' if back else '')+f'<div class="pgc" style="top:{104 if back else 72}px"><h3>{t}</h3>{body}</div>'+(tabs(tab) if tab is not None else '')
W,HH=402,874
ph=[]
first=curl(W,540,110)+status('7:00')+f'<div class="vb" style="left:28px;right:28px;bottom:{HH-540+120}px"><p class="verse" style="font-size:34px;line-height:51px">하루 네 번,<br>말씀이 사락<br>찾아갑니다.</p></div><div class="low" style="top:572px;left:24px;right:24px"><div class="four">'+''.join(f'<span>{chip(h)}{HR[h]["name"]}<small>{t}</small></span>' for h,t in zip(order,['오전 7:00','오후 12:20','오후 4:00','밤 9:30']))+f'</div></div><div class="foot">{btn("말씀 받기")}<p class="cap ctr">시간은 언제든 바꿀 수 있어요</p></div>'
ph+=[dev(W,HH,first,'첫 실행','질문 없이 바로 시작합니다.',id='p-first')]
for h in order: ph.append(dev(W,HH,home(W,HH,h,620),'골방 · '+HR[h]['name'],'라이트',h,id='p-'+h))
ph.append(dev(W,HH,home(W,HH,'night',620),'골방 · 밤','다크','night','dark',id='p-dark'))
ph.append(dev(W,HH,status('7:05')+readbar()+f'<div class="read" style="top:124px;left:28px;right:28px">{bib(30,36,(31,))}</div>'+f'<div class="fade"></div>{ACT}','읽기 · 구절 선택','색 면과 밑줄로 함께 표시합니다.',id='p-read'))
done=curl(W,580,120)+status('7:09')+f'<div class="vb" style="left:28px;right:28px;bottom:{HH-580+130}px"><p class="verse" style="font-size:34px;line-height:52px">오늘 5분,<br>마가복음이 사락<br>한 장 더 넘어갔어요.</p></div><div class="low" style="top:606px;left:24px;right:24px"><div class="field">감사나 묵상을 한 줄 남겨요 (선택)</div></div><div class="foot">{btn("마치기")}<span class="lnk">함께 나누기</span></div>'
ph.append(dev(W,HH,done,'읽기를 마침','종이가 더 크게 들립니다.','rest',id='p-done'))
books=lambda: ''.join(row(a,'',f'{b} {ic("go",18)}') for a,b in [('마태복음','28장'),('마가복음','16장'),('누가복음','24장'),('요한복음','21장'),('사도행전','28장')])
ph.append(dev(W,HH,titled('성경',f'<div class="cont">{curl(354,158,44)}<div><small>이어 읽기 · 마가복음 4:30</small><p class="verse" style="font-size:21px;line-height:33px;margin-top:8px">또 이르시되 우리가<br>하나님의 나라를 어떻게 비교하며</p></div></div><div class="seg"><span>구약</span><span class="on">신약</span></div>{books()}',1),'성경','이어 읽기가 가장 먼저 보입니다.',id='p-bible'))
kept=[('morning','겨자씨 한 알과 같으니','마가복음 4:31'),('rest','안심하라 내니 두려워하지 말라','마가복음 6:50'),('night','작은 자야 네 죄 사함을 받았느니라','마가복음 2:5')]
def keep(): return ''.join(f'<div class="kp"><i style="background:{HR[h]["light"]["page"]}"></i><div><p class="verse" style="font-size:20px;line-height:31px">{t}</p><p class="src" style="margin-top:4px">{s}</p></div></div>' for h,t,s in kept)
KS='<div class="seg"><span class="on">품은 말씀</span><span>남긴 한 줄</span><span>달력</span></div>'
ph.append(dev(W,HH,titled('말씀첩',KS+keep(),2),'말씀첩','받은 때의 색이 책갈피가 됩니다.',id='p-keep'))
ph.append(dev(W,HH,titled('말씀첩',KS+'<div class="empty"><p class="verse" style="font-size:24px;line-height:36px">아직 비어 있어요.</p><p class="cap">읽다가 마음에 머무는 구절을 눌러<br>품어 보세요.</p></div>',2),'말씀첩 · 빈 상태','재촉하지 않습니다.'))
def ns(): return row('말씀 알림','', tog())+row('오늘 하루 쉬기','',tog(False))+'<div class="gap"></div>'+''.join(row(a,b,tog(),chip(h)) for h,a,b in [('morning','아침을 여는 말씀','오전 7:00 · 사락 소리'),('noon','한낮의 말씀','오후 12:20 · 무음'),('rest','쉼의 말씀','오후 4:00 · 무음'),('night','하루를 덮는 말씀','밤 9:30 · 무음')])+row('시간 추가','',ic('go',18))+'<div class="gap"></div>'+row('잠금화면에 말씀 보이기','',tog())
ph.append(dev(W,HH,titled('알림',ns(),back=True),'알림 설정','네 시간이 네 색으로 구분됩니다.',id='p-noti'))
ph.append(dev(W,HH,titled('알림','<div class="note"><p><b>아이폰 설정에서 알림이 꺼져 있어요</b></p><p class="cap">켜 두면 정한 시간에 말씀이 찾아가요.</p>'+btn('아이폰 설정 열기')+'</div>'+'<div class="blk">'+ns()+'</div>',back=True),'알림 · 막힌 상태','다음 행동 하나만 보여 줍니다.'))
ph.append(dev(W,HH,titled('함께','<p class="cap" style="margin-bottom:18px">오늘 같은 본문을 펼친 사람들</p>'+''.join(row(a,b,f'<span class="lk">{r}</span>') for a,b,r in [('구역 식구들','오늘 세 사람이 불을 켰어요','말씀 보내기'),('우리 가족','아직 조용해요','말씀 보내기')])+'<div class="gap"></div>'+row('내 불빛 보이기','읽은 날 그룹에 불빛이 켜져요',tog())+row('신고하고 숨긴 사람','',ic('go',18)),back=True),'함께','순위와 연속 기록이 없습니다.'))
ph.append(dev(W,HH,titled('설정',row('읽기 시간','','5분')+row('함께 읽는 사람','',ic('go',18))+row('화면','','시스템')+row('글자','','보통')+row('알림','','네 번')+row('역본','','개역개정')+'<div class="gap"></div>'+row('로그인과 동기화','',ic('go',18))+row('문의','',ic('go',18))+'<div class="gap"></div>'+row('<span style="color:var(--danger)">계정 삭제</span>','',''),back=True),'설정','함께와 알림으로 들어갑니다.'))
ph.append(dev(W,HH,titled('말씀첩',KS+'<div class="note"><p><b>저장하지 못했어요</b></p><p class="cap">연결을 확인한 뒤 다시 시도해 주세요. <br>쓴 글은 그대로 있어요.</p><span class="btn s">다시 시도</span></div>'+keep(),2),'상태 · 저장 실패','무엇이 남아 있는지 알려 줍니다.'))
fin=curl(W,660,180)+status('7:12')+f'<div class="vb" style="left:28px;right:28px;bottom:{HH-660+190}px"><p class="verse" style="font-size:30px;line-height:46px">마가복음 한 권을<br>다 읽었어요.<br>하루 5분이 여기까지<br>데려왔네요.</p><p class="src" style="font-size:17px">다음은 시편에서 잠시 쉬어가요.</p></div><div class="foot">{btn("시편 펼치기")}</div>'
ph.append(dev(W,HH,fin,'완독','가장 크게 들린 한 장.','noon',id='p-fin'))
back=curl(W,620,92)+status('8:20')+f'<div class="vb" style="left:28px;right:28px;bottom:{HH-620+56}px"><p class="verse" style="font-size:32px;line-height:48px">책갈피는<br>그 자리에 있어요.</p><p class="src">오늘 5분부터 다시 펼쳐요.</p></div><div class="low" style="top:644px;left:24px;right:24px">{btn("이어서 펼치기")}</div>{tabs(0)}'
ph.append(dev(W,HH,back,'다시 옴','밀린 날을 세지 않습니다.','night'))

ph.append(dev(W,HH,status('7:08')+readbar()+f'<div class="read" style="top:124px;left:28px;right:28px">{bib(16,20,(),5)}<p class="cap" style="font-family:inherit;margin-top:28px;font-size:16px">오늘의 본문은 여기까지예요.</p></div><div class="foot">{btn("오늘 본문 마치기")}<span class="lnk">구약 이야기 5분 더</span></div>','읽기 · 본문 끝','10분 사용자에게만 한 줄이 더 보입니다.',id='p-end'))
ph.append(dev(W,HH,status('9:35')+readbar()+f'<div class="read" style="top:124px;left:28px;right:28px">{bib(30,36,(31,))}</div>{ACT}','읽기 · 다크','','night','dark',id='p-readdark'))
big=curl(W,700,60)+status('7:02')+f'<div class="top" style="top:62px;left:28px;right:18px"><p class="hi" style="font-size:24px;line-height:34px">좋은 아침이에요</p><span class="tap">{ic("gear",28)}</span></div><div class="vb" style="left:28px;right:24px;top:190px"><p class="verse" style="font-size:56px;line-height:80px">겨자씨<br>한 알과<br>같으니</p><p class="src" style="font-size:26px;line-height:38px">마가복음 4:31</p></div><div class="low" style="top:724px;left:24px;right:24px"><span class="btn" style="font-size:25px;height:104px;border-radius:30px;line-height:34px;text-align:center">오늘의 본문<br>5분쯤 읽기</span></div>'
ph.append(dev(W,HH,big,'골방 · 가장 큰 글자','말씀은 자르지 않고, 탭은 화면을 내리면 나옵니다.',id='p-big'))
days=''.join('<i></i>' for _ in range(6))+''.join(f'<span class="{"rd" if d in (3,4,6,9,10,11,14,17,18,19,21,23) else ""} {"td" if d==24 else ""}">{d}</span>' for d in range(1,31))
ph.append(dev(W,HH,titled('말씀첩',KS.replace('class="on">품은','>품은').replace('<span>달력','<span class="on">달력')+f'<p style="font-weight:600;margin:20px 0 12px">2026년 11월</p><div class="cal">'+''.join(f'<b>{x}</b>' for x in '월화수목금토일')+days+'</div><p class="cap" style="margin-top:18px">종이가 놓인 날은 말씀을 읽은 날이에요.</p>',2),'말씀첩 · 달력','연속 기록과 빈 날 표시가 없습니다.',id='p-cal'))
ph.append(dev(W,HH,titled('아침을 여는 말씀',row('시간','','오전 7:00')+row('요일','','매일')+row('소리','','사락')+row('미리 받아보기','',ic('go',18))+'<div class="gap"></div>'+row('기본값으로 되돌리기'),back=True),'알림 · 시간 편집','',id='p-edit'))
ph.append(dev(W,HH,titled('성경','<div class="note"><p><b>연결이 끊겼어요</b></p><p class="cap">받아 둔 본문은 그대로 읽을 수 있어요.</p></div>'+books(),1),'상태 · 오프라인',''))
ph.append(dev(W,HH,curl(W,620,92)+status('7:02')+f'<div class="vb" style="left:28px;right:28px;bottom:{HH-620+56}px"><p class="cap" style="font-size:15px">말씀을 펼치고 있어요</p></div>{tabs(0)}','상태 · 여는 중','깜빡이는 뼈대 없이 종이만 먼저 보입니다.'))
# 알림/위젯
lock=f'<div class="lock"><p>11월 24일 화요일</p><h4>7:00</h4></div><div class="ntf"><img src="icon/AppIcon-1024.png" alt=""><div><b>아침을 여는 말씀</b><p>겨자씨 한 알과 같으니<br>마가복음 4:31</p></div><small>지금</small></div>'
exp=f'<div class="exp">{curl(370,232,64)}<div class="vb" style="left:24px;right:24px;top:24px"><span class="cap">아침을 여는 말씀</span><div style="height:30px"></div>{vs("겨자씨 한 알과 같으니","마가복음 4:31",28,42)}</div></div><div class="menu"><span>마음에 품기</span><span>아멘</span><span>한 줄 남기기</span><span>한 시간 뒤</span></div>'
ou=[dev(W,HH,lock,'잠금화면 알림','판과 글꼴은 iOS가 그립니다.',id='p-lock',kind='phone wall'),dev(W,HH,exp,'길게 눌러 펼침','위 종이만 사락이 그립니다.',id='p-exp',kind='phone wall')]

nt=lambda t,b,k='지금': f'<div class="ntf in"><img src="icon/AppIcon-1024.png" alt=""><div><b>{t}</b><p>{b}</p></div><small>{k}</small></div>'
ou.append(dev(W,HH,f'<div class="lock"><p>11월 24일 화요일</p><h4>9:30</h4></div><div class="stk">'+nt('하루를 덮는 말씀','잠잠하라 고요하라 하시니 바람이 그치고<br>아주 잔잔하여지더라<br>마가복음 4:39')+nt('쉼의 말씀','안심하라 내니 두려워하지 말라<br>마가복음 6:50','오후 4:00')+nt('한낮의 말씀','심긴 후에는 자라서 모든 풀보다 커지며<br>마가복음 4:32','오후 12:20')+nt('사락','말씀이 찾아왔어요','내용 숨김')+'</div>','네 알림과 내용 숨김','',id='p-stack',kind='phone wall'))
def wid(w,h,body,cap,hour='morning',mode='light'): return f'<figure style="width:{max(w,150)}px"><div class="wid" style="width:{w}px;height:{h}px;{v(hour,mode)}">{body}</div><figcaption><b>{cap}</b></figcaption></figure>'
def wv(h,t,s,sz): return f'<div class="vb" style="left:18px;right:18px;top:18px">{vs(t,s,sz)}</div>'
wi=[wid(170,170,curl(170,170,40)+wv('morning','겨자씨<br>한 알과<br>같으니','막 4:31',21),'소형'),wid(364,170,curl(364,170,48,fill='var(--page)')+wv('rest','안심하라 내니<br>두려워하지 말라','마가복음 6:50',25),'중형','rest'),wid(364,382,curl(364,382,70)+f'<div class="vb" style="left:24px;right:24px;top:26px">{vs("잠잠하라 고요하라<br>하시니 바람이 그치고<br>아주 잔잔하여지더라","마가복음 4:39",27)}</div><div class="vb" style="left:24px;bottom:24px;width:200px">{btn("5분쯤 읽기","s")}</div>','대형 · 다크','night','dark'),
 wid(76,76,'<div class="circ">'+curl(34,40,15)+'</div>','잠금 원형'),wid(172,76,'<div class="rect" style="background:#6b615d"><p class="verse" style="color:#fff">안심하라 내니<br>두려워하지 말라</p></div>','잠금 사각'),wid(364,170,'<div class="rect" style="padding:20px 28px"><p class="verse" style="font-size:34px;line-height:50px;color:#ff5a4d">안심하라 내니<br>두려워하지 말라</p></div>','스탠바이 · 밤')]
# 듀오
STRIP='<div class="strip"><i></i><b>7:02</b><span></span></div>'
def duoh():
    a,b,g,t=V['morning']
    return curl(466,450,72)+STRIP+f'<div class="top" style="top:18px;left:28px;right:92px"><div><span class="cap">11월 24일 화요일</span><p class="hi">{g}</p></div><span><span class="tap">{ic("people")}</span><span class="tap">{ic("gear")}</span></span></div><div class="vb" style="left:28px;right:100px;bottom:284px">{vs(a,b,34)}</div><div class="low" style="top:472px;left:24px;right:92px">{btn(BTN)}<p class="cap ctr">{SUB}</p></div>'+tabs(0).replace('"tabs"','"tabs cl"')
STRIP2='<div class="strip"><b>7:05</b><span></span></div>'
duo=[dev(466,678,duoh(),'닫힘 · 골방','466×678 · 말씀과 버튼이 한 화면에.',id='d-closed'),
 dev(466,678,STRIP+readbar().replace('class="bar"','class="bar" style="top:12px;right:88px"')+f'<div class="read" style="top:76px;left:28px;right:96px">{bib(30,34,(31,))}</div>'+ACT.replace('class="acts"','class="acts cl"'),'닫힘 · 읽기','466×678',id='d-closedread')]
def spread(w,h,hour='morning',gut=475.5,mode='light',sz=36,ins=36):
    a,b,g,t=V[hour]; lw=int(gut)
    return curl(lw,h,96)+f'<div class="top" style="top:44px;left:40px;width:{lw-80}px"><div><span class="cap">11월 24일 화요일</span><p class="hi">{g}</p></div><span class="tap">{ic("gear")}</span></div><div class="vb" style="left:40px;width:{lw-120}px;bottom:170px">{vs(a,b,sz)}</div>{tabs(0).replace("tabs","tabs lf")}<div class="rp" style="left:{lw+28}px;width:{min(560,w-lw-28-ins)}px"><div class="bar in"><b>마가복음 4:30–5:20</b><span class="tap"><em>가</em></span><span class="tap">{ic("ear")}</span></div><div class="read in">{bib(30,34 if h<760 else 39,(31,))}</div><div class="rb">{btn("오늘 본문 마치기","s")}</div></div>'
duo.append(dev(951,669,spread(951,669,ins=96)+STRIP2,'펼침 가로 · 펼친 책','951×669 · 가운데 접힘선 양쪽 28pt를 비웁니다.',id='d-open'))
duo.append(dev(669,951,status('7:05')+readbar()+f'<div class="read" style="top:140px;left:54.5px;width:560px;font-size:21px;line-height:37px">{bib(30,39,(31,))}</div>{ACT}','펼침 세로 · 읽기','669×951 · 글줄 560pt 이하. 상태 표시는 위쪽에 있습니다.',id='d-port'))
half=curl(669,440,96)+f'<div class="vb" style="left:48px;right:90px;top:110px">{vs("잠잠하라 고요하라 하시니<br>바람이 그치고<br>아주 잔잔하여지더라","마가복음 4:39",36)}</div><div class="half"><div class="hb"><span class="tap">{ic("prev",28)}</span><span class="playb">{ic("pause",34)}</span><span class="tap">{ic("nextv",28)}</span></div><p class="ctr">마가복음 4:30–5:20 듣는 중</p><div class="pair">{btn("마음에 품기","g")}{btn("한 줄 남기기","g")}</div></div>'
duo.append(dev(669,951,half,'반쯤 접힘 · 듣기','위는 말씀, 아래는 조작. 접힘선에 아무것도 두지 않습니다.','night',id='d-half'))
duo.append(dev(951,669,f'<div class="pgc" style="top:40px;left:40px;width:395px;right:auto"><h3>말씀첩</h3>{KS}{keep()}</div>{tabs(2).replace("tabs","tabs lf")}<div class="rp" style="left:503px;width:352px;top:48px"><p class="verse" style="font-size:32px;line-height:50px">안심하라 내니<br>두려워하지 말라</p><p class="src">마가복음 6:50</p><div class="field" style="margin-top:36px;height:150px">한 줄 남기기</div></div>'+STRIP2,'펼침 가로 · 말씀첩','왼쪽 목록, 오른쪽 한 구절과 메모.','rest',id='d-keep'))
duo.append(dev(951,669,f'<div class="pgc" style="top:40px;left:40px;width:395px;right:auto"><h3>설정</h3>{row("읽기 시간","","5분")}{row("화면","","시스템")}{row("<b>알림</b>","","네 번")}{row("역본","","개역개정")}</div>{tabs(0).replace("tabs","tabs lf")}<div class="rp" style="left:503px;width:352px;top:40px"><h3 style="font-size:22px">알림</h3>{ns()}</div>'+STRIP2,'펼침 가로 · 알림 설정','설정과 상세를 나란히.',id='d-noti'))
def ipadhome():
    a,b,g,t='안심하라 내니<br>두려워하지 말라','마가복음 6:50','쉬어 가도 괜찮아요','4:03'
    return curl(834,930,170)+f'<div class="top" style="top:56px;left:72px;right:60px"><div><span class="cap">11월 24일 화요일</span><p class="hi">{g}</p></div><span class="tap">{ic("gear")}</span></div><div class="vb" style="left:72px;right:150px;bottom:{1210-930+130}px">{vs(a,b,52,78)}</div><div class="low" style="top:966px;left:72px;width:400px">{btn(BTN)}<p class="cap" style="margin-top:14px">{SUB}</p></div>{tabs(0)}'
ip=[dev(834,1210,ipadhome(),'iPad 세로 · 골방','834×1210','rest',id='i-port'),dev(1210,834,spread(1210,834,'morning',520,sz=42),'iPad 가로 · 펼친 책','1210×834 · 왼쪽 말씀, 오른쪽 본문.',id='i-land'),
 dev(1210,834,f'<div class="pgc" style="top:52px;left:56px;width:400px;right:auto"><h3>말씀첩</h3>{KS}{keep()}</div>{tabs(2).replace("tabs","tabs lf")}<div class="rp" style="left:540px;right:80px;top:60px;border-left:0"><p class="verse" style="font-size:44px;line-height:68px">작은 자야<br>네 죄 사함을<br>받았느니라</p><p class="src">마가복음 2:5</p><div class="field" style="margin-top:44px;height:180px">한 줄 남기기</div></div>','iPad 가로 · 말씀첩','다크','night','dark',id='i-keep')]
def watch(w,h,body,cap,note='',hour='morning',cls=''): return dev(w,h,f'<div class="wc {cls}" style="--wp:{HR[hour]["light"]["page"]};--page:#000;--flap:{HR[hour]["light"]["page"]};--next:{HR[nxt(hour)]["dark"]["page"]}">{body}</div>',cap,note,hour,'dark','watch',id='w-'+str(w)+cls+hour)
def wh(w,h,t,s,sz,time,c=44): return curl(w,h,c)+f'<b class="wt">{time}</b><div class="wv">{vs(t,s,sz,round(sz*1.42))}</div>'
wa=[watch(187,223,wh(187,223,'겨자씨<br>한 알과<br>같으니','막 4:31',25,'7:02',34),'말씀 · 42mm','187×223'),
 watch(208,248,wh(208,248,'안심하라 내니<br>두려워하지 말라','막 6:50',23,'4:03'),'말씀 · 46mm','208×248','rest'),
 watch(211,257,wh(211,257,'심긴 후에는<br>자라서 모든<br>풀보다 커지며','막 4:32',26,'12:24'),'말씀 · 49mm','211×257','noon'),
 watch(208,248,f'<b class="wt">4:00</b><div class="wn"><img src="icon/AppIcon-1024.png" alt=""><p>사락</p><small>쉼의 말씀</small></div>','짧게 보는 알림','','rest','a'),
 watch(208,248,'<b class="wt">4:00</b><div class="wl"><p class="verse" style="font-size:22px;line-height:31px">안심하라 내니<br>두려워하지 말라</p><p class="src">막 6:50</p><span>품기</span><span>아멘</span><span>나중에</span></div>','길게 보는 알림','아래로 [나중에]가 이어집니다.','rest','b'),
 watch(208,248,'<b class="wt">9:31</b><div class="wv" style="top:44px;bottom:auto"><p class="verse" style="font-size:22px;line-height:33px">잠잠하라<br>고요하라 하시니<br>바람이 그치고<br>아주<br>잔잔하여지더라</p></div><i class="crown"></i>','긴 구절','크라운으로 끝까지 읽습니다.','night','c'),
 watch(208,248,'<b class="wt">9:40</b><div class="wv dim"><p class="verse" style="font-size:24px;line-height:35px">겨자씨<br>한 알과 같으니</p><p class="src">막 4:31</p></div>','항상 표시','면을 끄고 글자만 남깁니다.','night','d'),
 watch(208,248,'<b class="wt">4:10</b><div class="wn"><p>말씀이<br>찾아왔어요</p><small>손목을 들면 보여요</small></div>','내용 숨김','','noon','e')]
cmp_=[wid(60,60,'<div class="circ dk">'+curl(28,33,12)+'</div>','원형',mode='dark'),wid(190,72,'<div class="rect"><p class="verse">안심하라 내니<br>두려워하지 말라</p><small>막 6:50</small></div>','직사각형','rest','dark'),wid(190,90,'<div class="rect"><small>쉼의 말씀</small><p class="verse">안심하라 내니<br>두려워하지 말라</p></div>','스마트 스택','rest','dark'),wid(190,36,'<div class="rect inl">막 6:50 · 다음 말씀 밤 9:30</div>','인라인','night','dark')]
# 시스템
def sw(h):
    d=HR[h]; return f'<div class="sw"><div style="--page:{d["light"]["page"]};--flap:{d["light"]["flap"]};--next:{HR[nxt(h)]["light"]["page"]}">{curl(270,200,60)}</div><b>{d["name"]}</b><small>라이트 {d["light"]["page"]}<br>다크 {d["dark"]["page"]}</small></div>'
base=''.join(f'<tr><td><i style="background:{T["color"]["light"][k]}"></i>{T["color"]["light"][k]}</td><td><i style="background:{T["color"]["dark"][k]}"></i>{T["color"]["dark"][k]}</td><th>{n}</th><td>{k}</td></tr>' for k,n in [('canvas','바탕'),('raised','올린 면'),('ink','글자'),('sub','보조 글자'),('line','선'),('primary','주 버튼'),('onPrimary','버튼 글자'),('danger','경고'),('control','꺼진 토글·입력 테두리')])
def sec(t,p,b,id): return f'<section id="{id}"><header><h2>{t}</h2><p>{p}</p></header>{b}</section>'
wrap=lambda l,c='': f'<div class="flow {c}">'+''.join(l)+'</div>'
comp=f'<div class="comps" style="{v("morning","light")}"><div>{btn(BTN)}{btn("누름","pr")}{btn("쓸 수 없음","off")}{btn("보조 버튼","g")}<span class="lnk">글자 버튼</span></div><div>{row("아침을 여는 말씀","오전 7:00 · 사락 소리",tog(),chip("morning"))}{row("쉼의 말씀","꺼짐",tog(False),chip("rest"))}<div class="seg" style="margin-top:20px"><span class="on">품은 말씀</span><span>남긴 한 줄</span><span>달력</span></div><div class="field">한 줄 남기기</div></div><div>{ACT.replace("acts","acts st-in")}{tabs(0).replace("tabs","tabs st-in")}</div></div>'
css=open(H+'/board.css').read()
out=f'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>사락 디자인 셋</title><style>{css}</style></head><body style="{v("morning","light")}">
<div class="cover"><div><h1>사락 디자인 셋</h1><p class="lead">빛이 물든 종이 한 장.<br>하루 네 번 색이 바뀌고, 종이가 사락 넘어갑니다.</p></div><div class="cv">{curl(620,420,120)}<div class="vb" style="left:48px;bottom:64px">{vs("겨자씨<br>한 알과 같으니","마가복음 4:31",46,68)}</div></div></div>
{sec('색','네 시간이 네 가지 파스텔입니다. 한 화면에는 한 색만 크게 쓰고, 들린 종이 아래로 다음 시간의 색이 비칩니다.',wrap([sw(h) for h in order],'sws')+f'<table class="tk"><thead><tr><td>라이트</td><td>다크</td><td>쓰임</td><td>이름</td></tr></thead>{base}</table><p class="ok">글자와 바탕 {len(rows)}개 조합을 계산했고, 가장 낮은 대비는 {min(r[2] for r in rows):.2f}:1입니다(기준 4.5:1).</p>','color')}
{sec('글자','말씀은 고운바탕, 화면 글자는 시스템 글꼴. 말씀이 언제나 가장 큽니다.','<div class="ty"><p class="verse" style="font-size:52px;line-height:78px">안심하라 내니</p><small>태블릿 말씀 52/78</small><p class="verse" style="font-size:32px;line-height:48px">안심하라 내니 두려워하지 말라</p><small>골방 말씀 36/54, 긴 구절은 26/40</small><p class="verse" style="font-size:19px;line-height:33px">또 이르시되 우리가 하나님의 나라를 어떻게 비교하며</p><small>읽기 19/33, 사용자 조절 14–28</small><p style="font-size:22px;font-weight:600">알림 설정</p><small>큰 제목 30/38, 제목 22/30</small><p style="font-size:17px">오늘의 본문 5분쯤 읽기</p><small>본문 17/25, 보조 15/22, 최소 13/18</small></div>','type')}
{sec('부품','모양은 세 가지뿐입니다. 종이 한 장, 둥근 막대, 가는 줄.',comp,'parts')}
{sec('iPhone','402×874pt',wrap(ph),'iphone')}
{sec('알림과 위젯','잠금화면 판은 iOS가 그립니다. 사락은 펼친 종이와 위젯만 그립니다.',wrap(ou)+wrap(wi),'outside')}
{sec('iPhone Duo','기기 이름이 아니라 쓸 수 있는 폭으로 바뀝니다. 안전 영역의 폭이 600pt 미만이면 한 장, 그 위는 글줄 560pt, 가로가 더 길고 820pt 이상이면 펼친 책.',wrap(duo),'duo')}
{sec('iPad','같은 폭 규칙을 씁니다. 화면 분할에서 좁아지면 한 장으로 돌아갑니다.',wrap(ip),'ipad')}
{sec('Apple Watch','검은 바탕에 시간의 색으로 글자를 쓰고, 종이 끝만 들립니다.',wrap(wa)+wrap(cmp_),'watch')}
</body></html>'''
open(R+'/사락-디자인셋.html','w').write(out)
json.dump(T,open(R+'/tokens.json','w'),ensure_ascii=False,indent=1)
# 앱 아이콘
def icon(bg,fl,nx):
    inner=curl(1024,1024,600).replace('class="pg"','').replace('var(--page)',bg).replace('var(--flap)',fl).replace('var(--next)',nx)
    return inner.replace('<svg ','<svg xmlns="http://www.w3.org/2000/svg" ',1)
for n,a in {'AppIcon':('#F8DFD3','#FFFDFC','#DDE8DC'),'AppIcon-Dark':('#3A2E2A','#F8DFD3','#8FA38F'),'AppIcon-Tinted':('#2A2A2A','#FFFFFF','#8A8A8A')}.items(): open(R+f'/icon/{n}.svg','w').write(icon(*a))
print(min(rows,key=lambda r:r[2]))
