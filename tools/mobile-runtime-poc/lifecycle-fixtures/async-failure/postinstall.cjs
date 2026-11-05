'use strict'
setInterval(() => {}, 1000)
setTimeout(() => {
  console.log('MOBILE_LIFECYCLE_ASYNC_FAILURE_STARTED')
  throw new Error('MOBILE_LIFECYCLE_ASYNC_FAILURE_THROWN')
}, 0)
