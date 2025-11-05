export const API = import.meta.env.VITE_API_BASE;

if (!API) {
  // Fail fast with a helpful message in dev
  throw new Error(
    "VITE_API_BASE is not set. Create apps/portal/.env (or .env.development) with VITE_API_BASE=<your API base URL>."
  );
}

export async function apiFetch(path, options = {}) {
  const token = localStorage.getItem("access_token"); // Or use id_token if needed

  const res = await fetch(path, {
    method: options.method || "GET",
    headers: {
      "Content-Type": "application/json",
      Authorization: token ? `Bearer ${token}` : undefined,
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!res.ok) throw new Error(await res.text());
  return res.json();
}
