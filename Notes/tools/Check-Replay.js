// Exercise replay rendering against a mock DOM/canvas. This is not visual QA.
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(process.env.REPLAY_HTML_PATH, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
let drawCalls = 0;
const context2d = new Proxy({}, {get:()=>()=>{drawCalls++;}});
const elements = new Map();
function element(id) {
  if (!elements.has(id)) elements.set(id, {
    value:id==='bot'?'all':'0', checked:true, innerHTML:'', textContent:'',
    getBoundingClientRect:()=>({width:1000,height:620,left:0,top:0}),
    getContext:()=>context2d, querySelectorAll:()=>[],
  });
  return elements.get(id);
}
const sandbox={document:{getElementById:element},window:{addEventListener:()=>{}},
  devicePixelRatio:1,requestAnimationFrame:()=>{},location:{reload:()=>{}},console};
vm.createContext(sandbox);
vm.runInContext(script,sandbox,{timeout:20000});
vm.runInContext('index=rounds[current].frames.length-1;draw();',sandbox,{timeout:20000});
const rows=(element('roster').innerHTML.match(/data-slot=/g)||[]).length;
if (!rows || !drawCalls || !element('time').textContent.includes('Game time')) throw Error('Replay did not render observations');
element('bot').value='1';element('bot').onchange();
if (!element('details').textContent.includes('Bot #1')) throw Error('Bot selection did not update details');
console.log(JSON.stringify({botRows:rows,canvasCalls:drawCalls,time:element('time').textContent,
  details:element('details').textContent.split('\n')[0],check:'mock DOM runtime passed; visual QA unavailable'}));
