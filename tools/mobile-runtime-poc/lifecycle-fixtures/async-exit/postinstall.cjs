'use strict'
setInterval(() => {}, 1000)
setTimeout(() => {
  console.log('MOBILE_LIFECYCLE_ASYNC_EXIT_PASS')
  process.exitCode = 1
  process.exit(0)
  throw new Error('async lifecycle continued after process.exit')
}, 10)
