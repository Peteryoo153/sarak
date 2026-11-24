def g(id,a,b,x1=0,y1=0,x2=0,y2=1): return f'<linearGradient id="{id}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"><stop stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'
SH='<filter id="s" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#6B4436" flood-opacity=".20"/></filter>'
def svg(defs,body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs>{SH}{defs}</defs>{body}</svg>'
# D 네 장이 넘어간다: 하나의 책등에서 네 시간의 종이가 차례로 들린다
def blade(d,f): return f'<path d="{d}" fill="{f}" filter="url(#s)"/>'
D=svg(g('bg','#F8CBB6','#EBA48C')+g('a','#FFFFFF','#FFEDE2')+g('b','#FFF1CF','#F9D48C')+g('c','#EAF3E8','#BBD6BC')+g('d','#FFFDFB','#FBE3D6'),
 '<rect width="1024" height="1024" fill="url(#bg)"/>'
 +blade('M506 846C420 720 280 660 96 672V434C270 420 430 500 506 640Z','url(#d)')
 +blade('M518 846C604 720 744 660 928 672V434C754 420 594 500 518 640Z','url(#c)')
 +blade('M516 846C570 700 700 600 890 572L852 330C700 380 566 500 512 660Z','url(#b)')
 +blade('M512 846C520 690 600 540 760 440L650 168C560 300 500 480 506 660Z','url(#a)'))
# E 말씀 위로 빛이 오른다
E=svg(g('sky','#FCE4D6','#F9CDB9')+g('sun','#FFF3DC','#FBD79A')+g('p1','#FFFFFF','#FFF1E8')+g('p2','#DCE9DA','#B9D3BA')+g('p3','#E3DCEE','#C6B9DC'),
 '<rect width="1024" height="1024" fill="url(#sky)"/><circle cx="512" cy="440" r="216" fill="url(#sun)"/>'
 '<path d="M0 548C190 480 400 512 512 640C624 512 834 480 1024 548V1024H0Z" fill="url(#p1)" filter="url(#s)"/>'
 '<path d="M0 690C190 622 400 654 512 776C624 654 834 622 1024 690V1024H0Z" fill="url(#p2)" filter="url(#s)"/>'
 '<path d="M0 832C190 764 400 796 512 912C624 796 834 764 1024 832V1024H0Z" fill="url(#p3)" filter="url(#s)"/>')
# F 겨자씨: 펼친 두 쪽이 떡잎이 된다
F=svg(g('bg','#FBE3D6','#F6C6B0')+g('l','#D8EAD5','#9CC49F',1,0,0,1)+g('r','#C2DDBF','#7DAE86',0,0,1,1)+g('st','#8DB690','#6E9D77')+g('p1','#FFFFFF','#FFF1E8')+g('p2','#FFF0CB','#F8D795'),
 '<rect width="1024" height="1024" fill="url(#bg)"/>'
 '<path d="M512 770C506 660 506 600 512 500" stroke="url(#st)" stroke-width="36" stroke-linecap="round" fill="none"/>'
 '<path d="M504 530C476 370 360 262 190 246C182 410 300 548 504 530Z" fill="url(#l)" filter="url(#s)"/>'
 '<path d="M522 506C528 316 646 182 834 150C854 346 736 514 522 506Z" fill="url(#r)" filter="url(#s)"/>'
 '<path d="M0 668C190 600 400 632 512 760C624 632 834 600 1024 668V1024H0Z" fill="url(#p1)" filter="url(#s)"/>'
 '<path d="M0 828C190 760 400 792 512 908C624 792 834 760 1024 828V1024H0Z" fill="url(#p2)" filter="url(#s)"/>')
N={'D-네장':D,'E-빛':E,'F-겨자씨':F}
for n,s in N.items(): open(n+'.svg','w').write(s)
h='<body style="margin:0;padding:40px;background:#fff;font:26px Apple SD Gothic Neo;width:1500px">'
for n in N:
    im=lambda z:f'<img src="{n}.svg" width={z} style="border-radius:{z*.225:.0f}px;margin-right:26px;vertical-align:bottom">'
    h+=f'<div style="display:flex;align-items:flex-end;margin-bottom:36px"><div style="width:160px">{n[0]}</div>{im(330)}<div style="padding:30px;background:#eee">{im(120)}{im(60)}{im(40)}{im(29)}</div><div style="padding:30px;background:#222">{im(120)}{im(60)}{im(40)}{im(29)}</div></div>'
open('compare.html','w').write(h)
