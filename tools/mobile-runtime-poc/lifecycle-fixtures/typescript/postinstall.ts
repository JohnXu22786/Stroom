type Result = { marker: string }
const result: Result = { marker: 'TypeScript lifecycle ran in Node Mobile' }
if (!process.env.STROOM_LIFECYCLE_MARKER) throw new Error('marker path was not passed')
require('node:fs').writeFileSync(process.env.STROOM_LIFECYCLE_MARKER, result.marker)
console.log('MOBILE_LIFECYCLE_TS_PASS')
