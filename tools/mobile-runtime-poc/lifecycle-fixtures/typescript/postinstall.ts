type Result = { marker: string }
const result: Result = { marker: 'TypeScript lifecycle ran in Node Mobile' }
require('node:fs').writeFileSync(
  require('node:path').join(__dirname, 'bridge-marker.txt'),
  result.marker,
)
console.log('MOBILE_LIFECYCLE_TS_PASS')
