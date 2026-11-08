(() => {
  const value = 'Stroom 学习 🙂';
  let decoded;
  try {
    decoded = Buffer.from(value, 'utf8').toString('utf8');
  } catch (error) {
    if (!(error instanceof RangeError && error.message === 'Index out of range')) {
      console.log('RESULT:FAIL');
      throw error;
    }
    console.log('IOS_RAW_UTF8_RANGEERROR:' + error.name + ':' + error.message);
    console.log('RESULT:PASS');
    return;
  }

  if (decoded !== value) {
    console.log('RESULT:FAIL');
    throw new Error('UTF-8 round-trip mismatch');
  }

  console.log('IOS_RAW_UTF8_ROUNDTRIP:' + Buffer.from(decoded, 'utf8').toString('hex'));
  console.log('RESULT:PASS');
})()
