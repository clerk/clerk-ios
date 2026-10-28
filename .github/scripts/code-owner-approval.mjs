import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const TRUSTED_ROLES = new Set(['admin', 'maintain']);

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
  return new RegExp(`^${anchored ? '' : '(?:.*/)?'}${body}${directory ? '/.*' : '(?:/.*)?'}$`);
}

function parseCodeowners(text) {
  return text
    .split('\n')
    .map(line => line.replace(/(^|\s)#.*$/, '').trim())
    .filter(line => line !== '')
    .map(line => {
      const [pattern, ...owners] = line.split(/\s+/);
      return { regex: patternRegex(pattern), owned: owners.length > 0 };
    });
}

// The last matching line wins, and a line with no owners leaves its files unowned, as on GitHub.
function ownedFiles(rules, paths) {
  return paths.filter(path => rules.findLast(rule => rule.regex.test(path))?.owned === true);
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

function client({ fetch, api, token, repo }) {
  return async (path, { missing } = {}) => {
    const response = await fetch(`${api}/repos/${repo}${path}`, {
      headers: { accept: 'application/vnd.github+json', authorization: `Bearer ${token}`, 'x-github-api-version': '2022-11-28' },
    });
    if (missing !== undefined && response.status === 404) {
      return missing;
    }
    if (!response.ok) {
      throw new Error(`GET ${path} answered ${response.status}: ${(await response.text()).slice(0, 300)}`);
    }
    return response.json();
  };
}

async function paged(get, path) {
  const items = [];
  for (let page = 1; ; page += 1) {
    const batch = await get(`${path}${path.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
    items.push(...batch);
    if (batch.length < 100) {
      return items;
    }
  }
}

async function trusted(get, login) {
  const { role_name: role } = await get(`/collaborators/${encodeURIComponent(login)}/permission`, { missing: { role_name: 'none' } });
  return TRUSTED_ROLES.has(role);
}

async function codeOwnerApproval({ fetch, api, token, repo, number, author, baseRef }) {
  const get = client({ fetch, api, token, repo });
  const codeowners = await get(`/contents/.github/CODEOWNERS?ref=${encodeURIComponent(baseRef)}`, { missing: null });
  const rules = codeowners === null ? [] : parseCodeowners(Buffer.from(codeowners.content, 'base64').toString('utf8'));
  const files = await paged(get, `/pulls/${number}/files`);
  const owned = ownedFiles(rules, [...new Set(files.flatMap(file => [file.filename, file.previous_filename].filter(Boolean)))]);
  if (owned.length === 0) {
    return { pass: true, message: 'No file under CODEOWNERS changed.' };
  }
  if (await trusted(get, author)) {
    return { pass: true, message: `${author} has maintain or admin access, so their change to CODEOWNERS files needs no other owner.` };
  }
  for (const login of approvers(await paged(get, `/pulls/${number}/reviews`), author)) {
    if (await trusted(get, login)) {
      return { pass: true, message: `${login} approved, and has maintain or admin access.` };
    }
  }
  const shown = owned.slice(0, 10).join(', ');
  return {
    pass: false,
    message: `This changes ${owned.length} CODEOWNERS file(s) (${shown}${owned.length > 10 ? ', ...' : ''}). It needs an approval from someone with maintain or admin access.`,
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

export { codeOwnerApproval, main, ownedFiles, parseCodeowners };

if (process.argv[1] !== undefined && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    process.exitCode = (await main(process.env)) ? 0 : 1;
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
