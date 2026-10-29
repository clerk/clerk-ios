import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

import { client, paged } from './github.mjs';

const TRUSTED_ROLES = new Set(['admin', 'maintain']);
const PROTECTED_PATHS = '.github/protected-paths';

const GLOB = { '**/': '(?:.*/)?', '/**': '(?:/.*)?', '**': '.*', '*': '[^/]*', '?': '[^/]' };

function patternRegex(pattern) {
  const directory = pattern.endsWith('/');
  const trimmed = directory ? pattern.slice(0, -1) : pattern;
  const anchored = trimmed.includes('/');
  const body = trimmed
    .replace(/^\//, '')
    .split(/(\*\*\/|\/\*\*|\*\*|\*|\?)/)
    .map(part => GLOB[part] ?? part.replace(/[.+^${}()|[\]\\]/g, '\\$&'))
    .join('');
  // As in CODEOWNERS, `docs/*` matches docs/a.md but not docs/b/c.md, so a wildcard last segment matches no descendants.
  const last = trimmed.slice(trimmed.lastIndexOf('/') + 1);
  const descendants = directory ? '/.*' : /[*?]/.test(last) && last !== '**' ? '' : '(?:/.*)?';
  return new RegExp(`^${anchored ? '' : '(?:.*/)?'}${body}${descendants}$`);
}

function parseProtectedPaths(text) {
  return text
    .split('\n')
    .map(line => line.replace(/(^|\s)#.*$/, '').trim())
    .filter(line => line !== '')
    .map(patternRegex);
}

function protectedFiles(patterns, paths) {
  return paths.filter(path => patterns.some(pattern => pattern.test(path)));
}

function approvers(reviews, author) {
  const latest = new Map();
  for (const review of reviews) {
    if (review.user && review.state !== 'COMMENTED' && review.state !== 'PENDING') {
      latest.set(review.user.login, review.state);
    }
  }
  return [...latest].filter(([login, state]) => state === 'APPROVED' && login !== author).map(([login]) => login);
}

async function trusted(get, login) {
  const { role_name: role } = await get(`/collaborators/${encodeURIComponent(login)}/permission`, { missing: { role_name: 'none' } });
  return TRUSTED_ROLES.has(role);
}

async function codeOwnerApproval({ fetch, api, token, repo, number, author, baseRef }) {
  const get = client({ fetch, api, token, repo });
  const list = await get(`/contents/${PROTECTED_PATHS}?ref=${encodeURIComponent(baseRef)}`, { missing: null });
  const patterns = list === null ? [] : parseProtectedPaths(Buffer.from(list.content, 'base64').toString('utf8'));
  const files = await paged(get, `/pulls/${number}/files`);
  const { changed_files: changed } = await get(`/pulls/${number}`);
  if (files.length < changed) {
    return { pass: false, message: `GitHub listed ${files.length} of the ${changed} changed files, so this check can't tell which are protected. Split the pull request.` };
  }
  const owned = protectedFiles(patterns, [...new Set(files.flatMap(file => [file.filename, file.previous_filename].filter(Boolean)))]);
  if (owned.length === 0) {
    return { pass: true, message: `No file listed in ${PROTECTED_PATHS} changed.` };
  }
  if (await trusted(get, author)) {
    return { pass: true, message: `${author} has maintain or admin access, so their change to protected files needs no other approval.` };
  }
  for (const login of approvers(await paged(get, `/pulls/${number}/reviews`), author)) {
    if (await trusted(get, login)) {
      return { pass: true, message: `${login} approved, and has maintain or admin access.` };
    }
  }
  const shown = owned.slice(0, 10).join(', ');
  return {
    pass: false,
    message: `This changes ${owned.length} protected file(s) (${shown}${owned.length > 10 ? ', ...' : ''}). It needs an approval from someone with maintain or admin access.`,
  };
}

async function main(env, { fetch = globalThis.fetch, out = process.stdout } = {}) {
  const missing = ['GITHUB_REPOSITORY', 'GITHUB_TOKEN', 'PR_NUMBER', 'PR_AUTHOR', 'BASE_REF'].filter(name => !env[name]);
  if (missing.length > 0) {
    throw new Error(`missing ${missing.join(', ')}`);
  }
  const { pass, message } = await codeOwnerApproval({
    fetch,
    api: env.GITHUB_API_URL || 'https://api.github.com',
    token: env.GITHUB_TOKEN,
    repo: env.GITHUB_REPOSITORY,
    number: env.PR_NUMBER,
    author: env.PR_AUTHOR,
    baseRef: env.BASE_REF,
  });
  out.write(pass ? `${message}\n` : `::error title=Code owner approval::${message}\n`);
  return pass;
}

export { codeOwnerApproval, main, parseProtectedPaths, protectedFiles };

if (process.argv[1] !== undefined && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = (await main(process.env)) ? 0 : 1;
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
