const fs = require('node:fs')
const path = require('node:path')
fs.writeFileSync(path.join(__dirname, 'bridge-marker.txt'), 'JS lifecycle ran in Node Mobile')
console.log('MOBILE_LIFECYCLE_JS_PASS')
