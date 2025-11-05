import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { apiFetch } from "../lib/api";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  async function handleEmailLogin(e) {
    e.preventDefault();
    setMessage("🔄 Logging in...");

    try {
      const r = await apiFetch("/auth/login", {
        method: "POST",
        body: { email, password },
      });

      localStorage.setItem("demo_token", r.token);
      setMessage("✅ Login successful!");
      navigate("/");
    } catch (err) {
      setMessage(`❌ ${err.message || "Login failed"}`);
    }
  }

  function handleCognitoLogin(e) {
    e.preventDefault();
    const clientId = "4cddgb64bfu2au7ce5t9fqgtjp";
    const redirectUri = encodeURIComponent("http://localhost:3000/callback");
    const responseType = "code";
    const scope = encodeURIComponent("openid profile email");
    const cognitoDomain = "https://schoolcloud-dev.auth.us-east-1.amazoncognito.com";

    const loginUrl = `${cognitoDomain}/oauth2/authorize?response_type=${responseType}&client_id=${clientId}&redirect_uri=${redirectUri}&scope=${scope}`;
    window.location.href = loginUrl;
  }

  return (
    <div style={{ margin: "2rem auto", maxWidth: 400 }}>
      <h2>Login</h2>

      <form onSubmit={handleEmailLogin}>
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          style={{ display: "block", width: "100%", marginBottom: "1rem" }}
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          style={{ display: "block", width: "100%", marginBottom: "1rem" }}
        />
        <button type="submit">Sign In</button>
      </form>

      <hr style={{ margin: "2rem 0" }} />
      <button onClick={handleCognitoLogin}>Login with Cognito</button>

      <p>{message}</p>
    </div>
  );
}

// Add if you don’t already have this helper:
async function apiFetch(path, options = {}) {
  const res = await fetch(path, {
    method: options.method || "GET",
    headers: {
      "Content-Type": "application/json",
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!res.ok) throw new Error(await res.text());
  return res.json();
}
