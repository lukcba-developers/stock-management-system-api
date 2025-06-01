import { useState } from "react";

export default function AdminLogin({ onLogin }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    const res = await fetch("/api/auth/admin-login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (data.success) {
      localStorage.setItem("token", data.token);
      onLogin && onLogin(data.user);
      window.location.reload();
    } else {
      setError(data.error || "Login incorrecto");
    }
  };

  return (
    <form onSubmit={handleSubmit} style={{ maxWidth: 350, margin: "2rem auto", padding: 24, border: "1px solid #eee", borderRadius: 8 }}>
      <h2>Login de Administrador</h2>
      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={e => setEmail(e.target.value)}
        required
        style={{ width: "100%", marginBottom: 12, padding: 8 }}
      />
      <input
        type="password"
        placeholder="Contraseña"
        value={password}
        onChange={e => setPassword(e.target.value)}
        required
        style={{ width: "100%", marginBottom: 12, padding: 8 }}
      />
      <button type="submit" style={{ width: "100%", padding: 10 }}>Ingresar</button>
      {error && <div style={{color: "red", marginTop: 8}}>{error}</div>}
    </form>
  );
} 