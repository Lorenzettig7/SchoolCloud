import { useEffect } from "react";
import { useNavigate } from "react-router-dom";

export default function CallbackPage() {
  const navigate = useNavigate();

  useEffect(() => {
    try {
      const url = new URL(window.location.href);
      const hash = url.hash.startsWith("#") ? url.hash.substring(1) : "";
      const params = new URLSearchParams(hash);

      const idToken = params.get("id_token");
      const accessToken = params.get("access_token");
      const err = params.get("error_description") || params.get("error");

      if (err) {
        console.error("Cognito error:", err);
        navigate("/login");
        return;
      }

      if (idToken) {
        localStorage.setItem("id_token", idToken);
        if (accessToken) localStorage.setItem("access_token", accessToken);

        // scrub the hash so refresh is safe
        window.history.replaceState(null, "", url.pathname);

        console.log("✅ Cognito login OK; tokens saved.");
        navigate("/"); // ⬅️ send to a route that actually exists
        return;
      }

      console.error("No tokens found on callback URL.");
      navigate("/login");
    } catch (e) {
      console.error("Callback processing error:", e);
      navigate("/login");
    }
  }, [navigate]);

  return <p>Processing login…</p>;
}

