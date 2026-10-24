/**
 * Node names of the cluster of an exam.
 *
 * The exams are written with placeholders ({{NODE01}}, {{NODE02}}, {{CONTROL_PLANE}}) instead of the names of
 * the nodes: the jumphost introspects the cluster when the exam is prepared (ckx-node-vars --write) and keeps
 * the result in /home/candidate/.kube/ckx-vars.json. The questions and the answers are rendered with it.
 */

const sshService = require('./sshService');
const logger = require('../utils/logger');

const DEFAULTS = { NODE01: 'node01', NODE02: 'node02', CONTROL_PLANE: 'k8s-api-server' };
const VARS_FILE = '/home/candidate/.kube/ckx-vars.json';
const SAFE_VALUE = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

const cache = new Map(); // examId -> vars

/**
 * Replace {{NAME}} placeholders with the values of vars (unknown names are left as they are)
 * @param {string} text
 * @param {Object} vars
 * @returns {string}
 */
function substitute(text, vars) {
  return String(text).replace(/\{\{\s*([A-Z0-9_]+)\s*\}\}/g, (match, name) => {
    const value = vars && vars[name];
    return typeof value === 'string' && SAFE_VALUE.test(value) ? value : match;
  });
}

/**
 * Names of the nodes of the cluster of the exam, with the defaults when the jumphost cannot tell
 * @param {string} examId
 * @returns {Promise<Object>}
 */
async function getNodeVars(examId) {
  if (examId && cache.has(examId)) {
    return cache.get(examId);
  }
  try {
    const result = await sshService.executeCommand(`cat ${VARS_FILE} 2>/dev/null`);
    if (result.exitCode === 0 && result.stdout && result.stdout.trim()) {
      const parsed = JSON.parse(result.stdout);
      const vars = { ...DEFAULTS };
      Object.keys(DEFAULTS).forEach((key) => {
        if (typeof parsed[key] === 'string' && SAFE_VALUE.test(parsed[key])) {
          vars[key] = parsed[key];
        }
      });
      if (examId) {
        cache.set(examId, vars);
      }
      return vars;
    }
  } catch (error) {
    logger.warn('Could not read the node names from the jumphost, using the defaults', { error: error.message });
  }
  return { ...DEFAULTS };
}

module.exports = { getNodeVars, substitute, DEFAULTS };
