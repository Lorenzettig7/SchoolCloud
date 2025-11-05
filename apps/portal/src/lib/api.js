export const API = import.meta.env.VITE_API_BASE || "https://bm25ryr7md.execute-api.us-east-1.amazonaws.com/prod";

if (!API) {
  throw new Error(
    "VITE_API_BASE is not set. Add it to your .env file: VITE_API_BASE=<your API base URL>."
  );
}

export async function apiFetch(path, { method = "GET", body, headers = {} } = {}) {
  const token = localStorage.getItem("id_token");
  const finalHeaders = {
    "Content-Type": "application/json",
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...headers,
  };

  const res = await fetch(`${API}${path}`, {
    method,
    headers: finalHeaders,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(text || `Request failed with status ${res.status}`);
  }

  const contentType = res.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return res.json();
  }
  return res.text();
}
