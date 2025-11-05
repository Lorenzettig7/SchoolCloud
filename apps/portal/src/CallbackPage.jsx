// apps/portal/src/CallbackPage.jsx
import { useEffect } from "react";
import { useNavigate } from "react-router-dom";

export default function CallbackPage() {
  const navigate = useNavigate();

  useEffect(() => {
    try {
      const url = new URL(window.location.href);

      // Implicit flow returns tokens in the URL hash: #id_token=...&access_token=...
      const hash = url.hash.startsWith("#") ? url.hash.substring(1) : "";
      const hashParams = new URLSearchParams(hash);

      const idToken = hashParams.get("id_token");
      const accessToken = hashParams.get("access_token");
      const err = hashParams.get("error_description") || hashParams.get("error");

      if (err) {
        console.error("Cognito error:", err);
        navigate("/login");
        return;
      }

      if (idToken) {
        localStorage.setItem("id_token", idToken);
        if (accessToken) localStorage.setItem("access_token", accessToken);

        // Clean the URL (remove the hash so refreshes don't re-run this)
        window.history.replaceState(null, "", url.pathname + url.search);

        // Go to your authenticated area
        navigate("/portal");
        return;
      }

      // If you see a "code" here, your app client is using Auth Code + PKCE.
      // This page is set up for Implicit flow; switch to PKCE handling if desired.
      const code = new URLSearchParams(url.search).get("code");
      if (code) {
        console.error(
          "Received authorization code but this callback is using the implicit flow. Enable token flow or implement PKCE."
        );
      } else {
        console.error("No tokens found on callback URL.");
      }

      navigate("/login");
    } catch (e) {
      console.error("Callback processing error:", e);
      navigate("/login");
    }
  }, [navigate]);

  return <p>Processing login…</p>;
}
