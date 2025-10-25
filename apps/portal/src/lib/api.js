export const API = import.meta.env.VITE_API_BASE;

if (!API) {
  // Fail fast with a helpful message in dev
  throw new Error(
    "VITE_API_BASE is not set. Create apps/portal/.env (or .env.development) with VITE_API_BASE=<your API base URL>."
  );
}

export async function apiFetch(path, { method = "GET", token, body } = {}) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    let detail = "";
    try {
      detail = await res.text();
    } catch {}
    throw new Error(`HTTP ${res.status}${detail ? ` – ${detail}` : ""}`);
  }
  return res.json();
}
