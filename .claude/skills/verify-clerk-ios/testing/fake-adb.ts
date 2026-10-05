let stdin = '';
process.stdin.on('data', (chunk: Buffer) => (stdin += chunk.toString()));
process.stdin.on('end', () => {
  console.log(JSON.stringify({ args: process.argv.slice(2), stdin }));
  process.exit(process.argv.includes('fails') ? 3 : 0);
});
