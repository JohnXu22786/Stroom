const fs = require('node:fs')
if (!process.env.STROOM_LIFECYCLE_MARKER) throw new Error('marker path was not passed')
fs.writeFileSync(process.env.STROOM_LIFECYCLE_MARKER, 'JS lifecycle ran in Node Mobile')
console.log('MOBILE_LIFECYCLE_JS_PASS')
