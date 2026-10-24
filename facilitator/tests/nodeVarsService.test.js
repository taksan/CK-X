// Run with: node --test tests/nodeVarsService.test.js
const test = require('node:test');
const assert = require('node:assert');

// the service only needs ssh2 through sshService when it reads the jumphost: stub it for the pure functions
require.cache[require.resolve('../src/services/sshService')] = {
  id: require.resolve('../src/services/sshService'),
  filename: require.resolve('../src/services/sshService'),
  loaded: true,
  exports: { executeCommand: async () => ({ exitCode: 1, stdout: '' }) },
};

const loggerPath = require.resolve('../src/utils/logger');
require.cache[loggerPath] = { id: loggerPath, filename: loggerPath, loaded: true, exports: { info() {}, warn() {}, error() {} } };

const { substitute, getNodeVars, DEFAULTS } = require('../src/services/nodeVarsService');

test('placeholders are replaced, unknown ones are kept', () => {
  const vars = { NODE01: 'worker-a', NODE02: 'worker-b', CONTROL_PLANE: 'cp-1' };
  assert.strictEqual(substitute('ssh {{NODE01}} and {{ NODE02 }} on {{CONTROL_PLANE}} {{OTHER}}', vars), 'ssh worker-a and worker-b on cp-1 {{OTHER}}');
});

test('a value that is not a plain host name is never injected', () => {
  assert.strictEqual(substitute('{{NODE01}}', { NODE01: 'a b; rm -rf /' }), '{{NODE01}}');
});

test('the defaults are used when the jumphost cannot tell', async () => {
  assert.deepStrictEqual(await getNodeVars('exam-without-vars'), DEFAULTS);
});
