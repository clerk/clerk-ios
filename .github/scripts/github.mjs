function client({ fetch, api, token, repo }) {
  return async (path, { missing, method = 'GET', body } = {}) => {
    const response = await fetch(`${api}/repos/${repo}${path}`, {
      method,
      headers: { accept: 'application/vnd.github+json', authorization: `Bearer ${token}`, 'x-github-api-version': '2022-11-28' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (missing !== undefined && response.status === 404) {
      return missing;
    }
    if (!response.ok) {
      throw new Error(`${method} ${path} answered ${response.status}: ${(await response.text()).slice(0, 300)}`);
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

export { client, paged };
