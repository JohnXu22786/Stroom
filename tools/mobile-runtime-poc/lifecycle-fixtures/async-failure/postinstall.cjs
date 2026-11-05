'use strict'
setInterval(() => {}, 1000)
setTimeout(() => {
  throw new Error('MOBILE_LIFECYCLE_ASYNC_FAILURE')
}, 0)
