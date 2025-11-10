export function getIdToken() {
  return localStorage.getItem("id_token");
}
export function getAccessToken() {
  return localStorage.getItem("access_token");
}
export function isAuthenticated() {
  const t = getIdToken();
  return !!t && t.split(".").length === 3; // crude JWT shape check
}
export function logout() {
  localStorage.removeItem("id_token");
  localStorage.removeItem("access_token");
  localStorage.removeItem("demo_token"); // optional: clear legacy
}
