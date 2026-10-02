const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {JSDOM} = require('jsdom');
const assets = path.resolve(__dirname, '../../assets/vendor/mathlive');

async function editor() {
  const dom = new JSDOM('<div id="problem"></div>',
    {runScripts:'dangerously', url:'https://stroom.test/editor.html', pretendToBeVisual:true});
  const w = dom.window;
  w.HTMLElement.prototype.attachInternals = () => ({setFormValue() {}, setValidity() {}, states:new Set()});
  const shadowQuery = w.ShadowRoot.prototype.querySelector;
  w.ShadowRoot.prototype.querySelector = function(selector) {
    return shadowQuery.call(this, selector.replace(/^:host\s*>\s*/, ''));
  };
  w.HTMLSlotElement.prototype.assignedNodes = () => [];
  w.HTMLSlotElement.prototype.assignedElements = () => [];
  for (const name of ["scrollIntoView", "scroll", "scrollTo"]) {
    w.HTMLElement.prototype[name] = () => {};
    w[name] = () => {};
  }
  w.AudioContext = class { constructor() { this.state = 'running'; } };
  w.__resizeObservers = [];
  w.ResizeObserver = class {
    constructor(callback) { this.callback = callback; this.targets = new Set(); w.__resizeObservers.push(this); }
    observe(target) { this.targets.add(target); }
    disconnect() { this.targets.clear(); }
    unobserve(target) { this.targets.delete(target); }
  };
  w.getComputedStyle = () => ({fontSize:'16px', fontFamily:'serif', direction:'ltr', getPropertyValue:() => ''});
  w.matchMedia = () => ({matches:false, addEventListener() {}, removeEventListener() {}});
  w.FontFace = class { constructor() { this.status = 'loaded'; } load() { return Promise.resolve(this); } };
  w.document.fonts = {check:() => true, ready:Promise.resolve(), add() {}};
  w.document.execCommand = () => true;
  w.document.queryCommandSupported = () => false;
  w.document.elementFromPoint = () => w.document.getElementById('formula');
  w.Range.prototype.getBoundingClientRect = () => ({x:0,y:0,width:100,height:24,top:0,bottom:24,left:0,right:100});
  w.Range.prototype.getClientRects = () => [];
  w.eval(fs.readFileSync(path.join(assets,'mathlive.min.js'),'utf8') + '\n//# sourceURL=https://stroom.test/mathlive.min.js');
  w.MathLive.MathfieldElement.fontsDirectory = 'https://stroom.test/fonts';
  w.MathLive.MathfieldElement.soundsDirectory = null;
  w.MathLive.MathfieldElement.keypressSound = null;
  w.MathLive.MathfieldElement.plonkSound = null;
  const field = w.document.createElement('math-field');
  field.id = 'formula';
  w.document.body.prepend(field);
  w.eval(fs.readFileSync(path.join(assets,'editor.js'),'utf8'));
  await new Promise(resolve => w.setTimeout(resolve,20));
  return {w, dom, field:w.document.getElementById('formula'), bridge:w.stroomMath};
}

test('nested fraction editing, cursor selection, and undo keep rendered math', async () => {
  const {dom, field, bridge} = await editor();
  try {
    bridge.setSource('', 0);
    bridge.command('insert', 'y=');
    bridge.command('insert', '\\frac{#0}{#?}');
    bridge.command('insert', 'x');
    bridge.command('insert', '#@^{2}');
    bridge.command('insert', '+1');
    bridge.command('next','');
    bridge.command('insert','2');
    bridge.command('next','');
    assert.match(field.getValue(), /\\frac\{x\^\{?2\}?\+1\}\{2\}/);
    const selected = JSON.stringify(field.selection);
    const source = bridge.snapshot().latex;
    bridge.setSource(source, 1);
    assert.equal(JSON.stringify(field.selection), selected);
    const end = field.lastOffset;
    field.selection = {ranges:[[0,end]],direction:'forward'};
    bridge.command('insert','z');
    assert.equal(bridge.snapshot().latex,'z');
    bridge.command('command','undo');
    assert.equal(bridge.snapshot().latex, source);
  } finally { dom.window.close(); }
});

test('source import preserves unsupported source and plain function meanings', async () => {
  const {dom, field, bridge} = await editor();
  try {
    const source = 'sin(x)+pi';
    assert.equal(bridge.setSource(source,2).latex, source);
    assert.match(field.getValue(), /\\sin/);
    bridge.command('insert', '+1');
    assert.match(bridge.snapshot().latex, /\\sin/);
    const unsupported = '\\unknowncommand{x}';
    assert.equal(bridge.setSource(unsupported,3).latex,unsupported);
    assert.equal(field.readOnly,true);
    assert.equal(bridge.command('insert','2').latex,unsupported);
  } finally { dom.window.close(); }
});

test('matrix cells and extra rows remain structured and editable', async () => {
  const {dom, field, bridge} = await editor();
  try {
    bridge.setSource('',0);
    bridge.command('insert','\\begin{pmatrix}#?&#?\\\\#?&#?\\end{pmatrix}');
    for (const number of ['1','2','3','4']) {
      bridge.command('insert',number);
      if (number !== '4') bridge.command('next','');
    }
    assert.match(field.getValue(), /\\begin\{pmatrix\}/);
    assert.match(field.getValue(), /1 & 2/);
    assert.equal(field.errors.length,0);
    bridge.command('command','addRowAfter');
    bridge.command('insert','5');
    assert.match(bridge.snapshot().latex,/5/);
  } finally { dom.window.close(); }
});


test('legacy roots and absolute values import as editable structures', async () => {
  const {dom, field, bridge} = await editor();
  try {
    for (const [source, latex] of [['sqrt(x+1)', '\\sqrt{x+1}'], ['abs(x-1)', '\\left|x-1\\right|']]) {
      assert.equal(bridge.setSource(source,1).latex,source);
      assert.equal(field.getValue(),latex);
      bridge.command('insert','+1');
      assert.equal(bridge.snapshot().latex,latex + '+1');
    }
  } finally { dom.window.close(); }
});


test('legacy inverse trig names remain operators in plain and mixed source', async () => {
  const {dom, field, bridge} = await editor();
  try {
    for (const name of ['asin','acos','atan']) {
      for (const argument of ['x', 'x^{2}']) {
        const source = `${name}(${argument})`;
        bridge.setSource(source,1);
        assert.match(field.getValue(),new RegExp('\\\\arc' + name.slice(1)));
        bridge.command('insert','+1');
        assert.match(bridge.snapshot().latex,new RegExp('\\\\arc' + name.slice(1)));
      }
    }
  } finally { dom.window.close(); }
});

test('post-render growth reports the formula and error-panel height', async () => {
  const {dom, field, bridge} = await editor();
  try {
    bridge.setSource('x',1);
    const messages = [];
    dom.window.flutter_inappwebview = {callHandler: (_, payload) => messages.push(payload)};
    const observer = dom.window.__resizeObservers.find(o => o.targets.has(field));
    assert.ok(observer, 'The wrapper must observe the host after asynchronous math layout');
    field.getBoundingClientRect = () => ({height:140});
    dom.window.document.getElementById('problem').getBoundingClientRect = () => ({height:12});
    observer.callback([]);
    assert.equal(messages.at(-1).height,152);
    assert.equal(messages.at(-1).latex,'x');
  } finally { dom.window.close(); }
});
