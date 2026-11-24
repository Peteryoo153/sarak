// node shoot.mjs : board.html을 정확한 픽셀 크기의 PNG로 저장 (Chrome 필요)
import {spawn} from 'node:child_process';import fs from 'node:fs';import path from 'node:path';import os from 'node:os';
const H=import.meta.dirname,OUT=path.join(H,'..'),port=9388,prof=fs.mkdtempSync(path.join(os.tmpdir(),'sarak-'));
const c=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--remote-debugging-port='+port,'--user-data-dir='+prof,'--no-first-run','--hide-scrollbars','about:blank'],{stdio:'ignore'});
const sl=ms=>new Promise(r=>setTimeout(r,ms));let t;for(let i=0;i<80;i++){try{t=(await(await fetch(`http://127.0.0.1:${port}/json`)).json()).find(x=>x.type==='page');if(t)break}catch{}await sl(250)}
const ws=new WebSocket(t.webSocketDebuggerUrl);await new Promise(r=>ws.onopen=r);let n=0;const p={};ws.onmessage=e=>{const m=JSON.parse(e.data);p[m.id]?.(m.result||m.error)};const s=(method,params={})=>new Promise(r=>{const id=++n;p[id]=r;ws.send(JSON.stringify({id,method,params}))});
const ev=async e=>(await s('Runtime.evaluate',{expression:e,awaitPromise:true,returnByValue:true})).result.value;
await s('Emulation.setDeviceMetricsOverride',{width:2900,height:2900,deviceScaleFactor:1,mobile:false});await s('Page.enable');await s('Page.navigate',{url:'file://'+path.join(H,'board.html')});await sl(3000);
await ev('Promise.all([document.fonts.load("20px GB"),...[...document.images].map(i=>i.decode())]).then(()=>1)');
console.log('font',await ev('document.fonts.check("20px GB")'));
for(const id of JSON.parse(await ev('JSON.stringify([...document.querySelectorAll("section")].map(e=>e.id))'))){
 await ev(`document.querySelectorAll('section').forEach(e=>e.style.display=e.id==='${id}'?'block':'none')`);
 const [w,h]=JSON.parse(await ev(`(()=>{const r=document.getElementById('${id}').getBoundingClientRect();const t=document.querySelector('#${id} h1').getBoundingClientRect(),d=document.querySelector('#${id} .dev').getBoundingClientRect();return JSON.stringify([r.width,r.height])})()`));
 const chk=await ev(`(()=>{const b=document.getElementById('${id}').getBoundingClientRect(),t=document.querySelector('#${id} h1').getBoundingClientRect(),d=[...document.querySelectorAll('#${id} .dev')].map(e=>e.getBoundingClientRect());return (t.right>b.right?' 글자넘침':'')+(d.some(x=>x.top<t.bottom&&x.left<t.right)?' 겹침':'')})()`);
 const d=await s('Page.captureScreenshot',{format:'png',clip:{x:0,y:0,width:w,height:h,scale:1}});
 const dir=path.join(OUT,id.replace(/-\d.*/,''));fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,id+'.png'),Buffer.from(d.data,'base64'));console.log(id,w,h,chk);}
await s('Browser.close');process.exit(0)
