import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { apiFetch } from "./api";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const navigate = useNavigate();

  async function handleLogin(e) {
    e.preventDefault();
    setMessage("Logging in...");
    try {
      const r = await apiFetch("/auth/login", {
        method: "POST",
        body: { email, password },
      });
      localStorage.setItem("demo_token", r.token);
      setMessage("✅ Login successful!");
      navigate("/"); // back to portal
    } catch (err) {
      setMessage(`❌ ${err.message || "Login failed"}`);
    }
  }

  return (
    <div style={{ margin: "2rem auto", maxWidth: 400 }}>
      <h2>Login</h2>
      <form onSubmit={handleLogin}>
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
      <p>{message}</p>
    </div>
  );
}
