import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { apiFetch } from "../lib/api";
import { isAuthenticated } from "../lib/auth";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  useEffect(() => {
    if (isAuthenticated()) {
      navigate("/");   // already logged in; don't trigger Cognito again
    }
  }, [navigate]);

  async function handleEmailLogin(e) {
    e.preventDefault();
    setMessage("🔄 Logging in...");
    try {
      const r = await apiFetch("/auth/login", {
        method: "POST",
        body: { username: email, password },
      });
      localStorage.setItem("demo_token", r.token);  // demo-only path
      setMessage("✅ Login successful!");
      navigate("/");
    } catch (err) {
      setMessage(`❌ ${err.message || "Login failed"}`);
    }
  }

  function handleCognitoLogin(e) {
    e.preventDefault(); // important inside <form>
    const domain = import.meta.env.VITE_COGNITO_DOMAIN;
    const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID;
    const redirectUri = `${window.location.origin}/callback`;
    const responseType = "token id_token";
    const scope = encodeURIComponent("openid email profile");

    const loginUrl =
      `${domain}/oauth2/authorize` +
      `?response_type=${encodeURIComponent(responseType)}` +
      `&client_id=${clientId}` +
      `&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&scope=${scope}`;

    console.log("Cognito authorize URL:", loginUrl);
    window.location.href = loginUrl;
  }

  return (
    <div style={{ margin: "2rem auto", maxWidth: 400 }}>
      <h2>Login</h2>

      <form onSubmit={handleEmailLogin}>
        <input type="email" placeholder="Email" value={email}
               onChange={(e) => setEmail(e.target.value)} required
               style={{ display: "block", width: "100%", marginBottom: "1rem" }} />
        <input type="password" placeholder="Password" value={password}
               onChange={(e) => setPassword(e.target.value)} required
               style={{ display: "block", width: "100%", marginBottom: "1rem" }} />
        <button type="submit">Sign In</button>
      </form>

      <hr style={{ margin: "2rem 0" }} />

      {/* make sure this isn't type="submit" */}
      <button type="button" onClick={handleCognitoLogin}>Login with Cognito</button>

      <p>{message}</p>
    </div>
  );
}
