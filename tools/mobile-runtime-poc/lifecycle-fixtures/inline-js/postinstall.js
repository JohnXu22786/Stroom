'use strict'
const fs = require('node:fs')
fs.writeFileSync(process.env.STROOM_LIFECYCLE_MARKER, 'Inline JS lifecycle ran in Node Mobile')
console.log('MOBILE_LIFECYCLE_INLINE_JS_PASS')
