BG='''<rect width="1024" height="1024" fill="#DDE8DC"/><path d="M0 0H1024V830C830 900 560 1024 0 1024Z" fill="#FFFDFC"/><path d="M0 0H1024V690C840 790 560 1024 0 1024Z" fill="#F8DFD3"/>'''
INK='#4A3733'; R='#D9957F'
A=f'''<g transform="translate(-52 -46) scale(1.1)"><path d="M500 352C432 286 322 268 214 300V664C322 632 432 650 500 716Z" fill="{INK}"/>
<path d="M524 352C590 288 690 268 780 292V652C690 634 590 652 524 716Z" fill="{R}"/>
<path d="M524 352C584 262 700 200 826 176C806 318 806 436 800 548C704 560 594 620 524 716Z" fill="{INK}"/></g>'''
B=f'''<path d="M596 0H664V548L596 500Z" fill="{R}"/><path d="M360 0H612V690L486 600L360 690Z" fill="{INK}"/>'''
C=f'''<g transform="translate(-22 -62) scale(1.02)"><path d="M459 205C459 188 474 182 487 192L633 300C692 346 716 440 680 473Q665 486 645 490C715 530 738 600 738 650C738 740 680 808 602 808C575 808 548 800 525 783L345 657Q326 643 326 620L328 271A15 15 0 0 1 357 271L356 608Q356 628 370 638L553 765C568 775 585 779 602 779C640 779 668 755 669 737Q669 722 655 712L470 585Q456 575 456 558Z" fill="{INK}"/>
<g fill="none" stroke="{R}" stroke-width="13" stroke-linecap="round"><path d="M384 276V596Q384 616 400 627L590 756"/><path d="M420 258V584Q420 602 434 612L628 744"/></g></g>'''
D={'A-펼친책':A,'B-책갈피':B,'C-기존로고':C}
for n,s in D.items(): open(f'{n}.svg','w').write(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{BG}{s}</svg>')
h='<body style="margin:0;padding:40px;background:#fff;font:26px Apple SD Gothic Neo;width:1500px">'
for n in D:
    im=lambda z:f'<img src="{n}.svg" width={z} style="border-radius:{z*.225:.0f}px;margin-right:26px;vertical-align:bottom">'
    h+=f'<div style="display:flex;align-items:flex-end;margin-bottom:36px"><div style="width:160px">{n[0]}</div>{im(330)}<div style="padding:30px;background:#eee">{im(120)}{im(60)}{im(40)}{im(29)}</div><div style="padding:30px;background:#222">{im(120)}{im(60)}{im(40)}{im(29)}</div></div>'
open('compare.html','w').write(h)
