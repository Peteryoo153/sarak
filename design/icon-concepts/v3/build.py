def g(id,a,b,x1=0,y1=0,x2=0,y2=1): return f'<linearGradient id="{id}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"><stop stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'
SH='<filter id="s" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#6B4436" flood-opacity=".20"/></filter>'
def svg(defs,body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>{SH}{defs}</defs>{body}</svg>'

def heart(dy,k,l,r):
    L='M512 372C470 250 236 212 172 392C122 560 330 700 512 842Z'; Rr='M512 372C554 250 788 212 852 392C902 560 694 700 512 842Z'
    return f'<g transform="translate({512*(1-k):.1f} {dy+560*(1-k):.1f}) scale({k})"><g filter="url(#s)"><path d="{L}" fill="url(#{l})"/><path d="{Rr}" fill="url(#{r})"/></g></g>'
G=svg(g('bg','#FBDDCD','#F3BBA3')+g('l1','#FFFFFF','#FBE4D8',0,0,1,0)+g('r1','#FFEFE5','#FFFFFF',0,0,1,0)+g('l2','#FFF3D4','#F7D692')+g('l3','#DCEBDA','#B4D1B6'),
 '<rect width="1024" height="1024" fill="url(#bg)"/>'+heart(14,1.0,'l3','l3')+heart(-22,1.0,'l2','l2')+heart(-60,1.0,'l1','r1')
 +'<path d="M512 314V778" stroke="#E9B7A0" stroke-width="7" stroke-linecap="round" opacity=".7"/>')
f=lambda p,c:f'<polygon points="{p}" fill="{c}" stroke="{c}" stroke-width="7" stroke-linejoin="round"/>'
H=svg(g('bg','#F9CDB8','#EBA38B')+g('w','#FFFFFF','#FFF0E6')+g('w2','#FFF4D9','#F6D58F')+g('b','#FFFFFF','#F7DDD0')+g('t','#DDEBDA','#A9CBAC')+g('h','#E7DFF2','#BFB0DA'),
 '<rect width="1024" height="1024" fill="url(#bg)"/><g filter="url(#s)" transform="translate(-40 18) scale(1.06)">'
 +f('560,560 700,196 742,540','url(#w2)')+f('222,566 126,742 420,640','url(#t)')+f('222,566 420,640 560,760 742,540 470,520','url(#b)')+f('742,540 880,486 792,584 690,602','url(#h)')+f('430,566 300,170 664,548 560,620','url(#w)')+'</g>')
I=svg(g('wall','#D9CFEA','#B8A9D6')+g('fl','#F8D9CB','#F0BBA4')+g('lt','#FFF6DF','#FBD98F')+g('dr','#FFFFFF','#FBE6DB',1,0,0,0)+g('ray','#FFF0C6','#F9D48A'),
 '<rect width="1024" height="1024" fill="url(#wall)"/><rect y="742" width="1024" height="282" fill="url(#fl)"/>'
 '<polygon points="322,742 642,742 930,1024 150,1024" fill="url(#ray)" opacity=".92"/>'
 '<rect x="322" y="214" width="320" height="528" rx="10" fill="url(#lt)"/>'
 '<path d="M642 214Q642 208 650 205L800 150Q812 146 812 160V836Q812 850 800 844L650 748Q642 744 642 736Z" fill="url(#dr)" filter="url(#s)"/>')
N={'G-마음책':G,'H-종이새':H,'I-골방':I}
for n,s in N.items(): open(n+'.svg','w').write(s)
h='<body style="margin:0;padding:40px;background:#fff;font:26px Apple SD Gothic Neo;width:1500px">'
for n in N:
    im=lambda z:f'<img src="{n}.svg" width={z} style="border-radius:{z*.225:.0f}px;margin-right:26px;vertical-align:bottom">'
    h+=f'<div style="display:flex;align-items:flex-end;margin-bottom:36px"><div style="width:160px">{n[0]}</div>{im(330)}<div style="padding:30px;background:#eee">{im(120)}{im(60)}{im(40)}{im(29)}</div><div style="padding:30px;background:#222">{im(120)}{im(60)}{im(40)}{im(29)}</div></div>'
open('compare.html','w').write(h)
