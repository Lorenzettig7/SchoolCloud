export const API = import.meta.env.VITE_API_BASE;

if (!API) {
  // Fail fast with a helpful message in dev
  throw new Error(
    "VITE_API_BASE is not set. Create apps/portal/.env (or .env.development) with VITE_API_BASE=<your API base URL>."
  );
}

export async function apiFetch(path, options = {}) {
  const token = localStorage.getItem("id_token");

  const res = await fetch(`${import.meta.env.VITE_API_BASE}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: token ? `Bearer ${token}` : "",
      ...options.headers,
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!res.ok) {
    throw new Error(await res.text());
  }
  return res.json();
}

