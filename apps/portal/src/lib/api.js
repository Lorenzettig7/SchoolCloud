const API_BASE = import.meta.env.VITE_API_BASE;

export async function apiFetch(path, { method = "GET", body, headers = {} } = {}) {
  const token = localStorage.getItem("access_token") || localStorage.getItem("id_token");

  const finalHeaders = {
    ...(body && !(body instanceof FormData) ? { "Content-Type": "application/json" } : {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...headers,
  };

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: finalHeaders,
    body: body
      ? body instanceof FormData
        ? body
        : typeof body === "string"
          ? body
          : JSON.stringify(body)
      : undefined,
  });

  if (res.status === 401) {
    localStorage.removeItem("access_token");
    localStorage.removeItem("id_token");
  }
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(text || `${res.status} ${res.statusText}`);
  }
  const ct = res.headers.get("content-type") || "";
  return ct.includes("application/json") ? res.json() : res.text();
}

// 👇 Provide a named export `API` that supports both styles: API('/path') and API.get('/path')
export const API = Object.assign(
  (path, opts) => apiFetch(path, opts),
  {
    get: (path, opts) => apiFetch(path, { method: "GET", ...opts }),
    post: (path, body, opts) => apiFetch(path, { method: "POST", body, ...opts }),
    put: (path, body, opts) => apiFetch(path, { method: "PUT", body, ...opts }),
    del: (path, opts) => apiFetch(path, { method: "DELETE", ...opts }),
  }
);
