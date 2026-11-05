'use strict'
const fs = require('node:fs')
setTimeout(async () => {
  await fs.promises.writeFile(
    process.env.STROOM_LIFECYCLE_MARKER,
    'Async JS lifecycle ran in Node Mobile',
  )
  console.log('MOBILE_LIFECYCLE_ASYNC_JS_PASS')
}, 10)
