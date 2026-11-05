'use strict'
setTimeout(() => {
  process.exitCode = 1
  console.log('MOBILE_LIFECYCLE_ASYNC_EXIT_DEFAULT')
  process.exit()
  throw new Error('async lifecycle continued after process.exit')
}, 0)
