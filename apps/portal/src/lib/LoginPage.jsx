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
        body: { username: email, password },
      });

      localStorage.setItem("demo_token", r.token);
      setMessage("✅ Login successful!");
      navigate("/");
    } catch (err) {
      setMessage(`❌ ${err.message || "Login failed"}`);
    }
  }

function handleCognitoLogin() {
  const domain = "https://schoolcloud-dev.auth.us-east-1.amazoncognito.com";
  const clientId = "4vljm45is9ejulo4fhoo5a1bp"; // your portal.secureschoolcloud.org client
  const redirectUri = "http://localhost:3000/callback";
  const responseType = "token"; // implicit flow
  const scope = encodeURIComponent("openid email profile");

  const loginUrl = `${domain}/oauth2/authorize?response_type=${responseType}&client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&scope=${scope}`;

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
