'use strict'
setTimeout(() => {
  process.exitCode = 17
  console.log('MOBILE_LIFECYCLE_ASYNC_EXIT_DEFAULT')
  process.exit()
  console.log('MOBILE_LIFECYCLE_ASYNC_EXIT_CONTINUED')
  throw new Error('async lifecycle continued after process.exit')
}, 0)
