import React, { useMemo, useState } from "react";
import { API, apiFetch } from "./lib/api";


// SchoolCloud Interactive Portal — Single-file React starter
// Tailwind classes only. Replace mock handlers with real API calls when wiring to AWS.
// Suggested wiring notes are inline as comments.

export default function SchoolCloudPortal() {
  const [activeTab, setActiveTab] = React.useState("overview");
  const [expandedNodes, setExpandedNodes] = React.useState({});
  const [ciRuns, setCiRuns] = React.useState([]);
  const [policyView, setPolicyView] = React.useState("boundary");

  const [token, setToken] = React.useState(
  localStorage.getItem("access_token") || localStorage.getItem("id_token") || null
);


  // Forms
  const [signupForm, setSignupForm] = React.useState({
    email: "", password: "", role: "student", school_id: "", dob: ""
  });
  const [loginForm, setLoginForm] = React.useState({ email: "", password: "" });

  // Activity feed
  const [events, setEvents] = React.useState([]);
  const lastTs = React.useRef(0);

  // Poll events every 3s when logged in
  React.useEffect(() => {
    if (!token) return;
    const t = setInterval(async () => {
      try {
        const res = await fetch(`${API}/events?since=${lastTs.current}`, {
          headers: { Authorization: `Bearer ${token}` }
        });
        if (!res.ok) return;
        const batch = await res.json();
        if (batch.length) {
          setEvents(prev => [...batch, ...prev].slice(0, 100));
          lastTs.current = Math.max(lastTs.current, ...batch.map(e => e.ts || 0));
        }
      } catch {}
    }, 3000);
    return () => clearInterval(t);
  }, [token]);

  // Helpers to add optimistic feed messages
  function addOptimistic(msg) {
    const ts = Date.now();
    setEvents(prev => [{ ts, type: "client", status: "PENDING", message: msg }, ...prev]);
  }

  // Actions
  async function doSignup(e) {
    e.preventDefault();
    addOptimistic("Creating account…");
    const r = await apiFetch("/auth/signup", { method: "POST", body: signupForm });
    localStorage.setItem("access_token", r.token);
    setToken(r.token);
  }

  async function doLogin(e) {
    e.preventDefault();
    addOptimistic("Logging in…");
    const r = await apiFetch("/auth/login", { method: "POST", body: loginForm });
    localStorage.setItem("id_token", r.token);
    setToken(r.token);
  }

  async function setEncryption(enc) {
    addOptimistic(`Setting encryption policy: ${enc}…`);
    await apiFetch("/identity/policy", { method: "POST", token, body: { encryption: enc } });
  }

  async function addToGroup(group) {
    addOptimistic(`Adding to ${group} group…`);
    await apiFetch("/identity/group", { method: "POST", token, body: { group } });
  }

  // Small feed renderer
  function ActivityFeed() {
    return (
      <div className="space-y-2 text-sm">
        {events.map((e, i) => (
          <div
            key={`${e.ts || i}-${e.id || e.action || e.message || "row"}`}
            className="flex items-start gap-2"
          >
            <span className="text-slate-400 w-24 tabular-nums">
              {new Date(e.ts || Date.now()).toLocaleTimeString()}
            </span>
            <span className={
              e.status === "PENDING" ? "text-amber-400" :
              e.status === "OK" ? "text-emerald-400" : "text-rose-400"
            }>
              {e.message}
            </span>
          </div>
        ))}
      </div>
    );
  }


  function now() {
    return new Date().toLocaleString();
  }

  // ---- MOCK HANDLERS: replace with real endpoints ----
  async function simulate(action) {
    // Example wiring (replace with your URLs):
    // const res = await fetch("https://<api-id>.execute-api.us-east-1.amazonaws.com/nonprod/simulate", {
    //   method: "POST",
    //   headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    //   body: JSON.stringify({ action })
    // });
    // const data = await res.json();

    const id = Math.random().toString(36).slice(2, 8);
    const status = action === "deploy-bad-canary" ? "ROLLED_BACK" : "BLOCKED";
    const row = {
      id,
      time: now(),
      action,
      status,
      detail: mockDetail(action)
    };
    setEvents((prev) => [row, ...prev].slice(0, 50));
  }

  function mockDetail(action) {
    switch (action) {
      case "scp-deny":
        return "CloudTrail: AccessDenied by SCP DenyUnencryptedObjectUploads";
      case "waf-block":
        return "WAF: Rule BurstLimitSchoolHours triggered; request blocked";
      case "unencrypted-put":
        return "S3 PutObject without SSE rejected (SCP + bucket policy)";
      case "login-anomaly":
        return "SageMaker flagged after-hours login from new ASN → Security Hub";
      case "deploy-bad-canary":
        return "10% canary failed health checks, auto-rollback executed";
      default:
        return "Event recorded";
    }
  }

  function triggerCiRun(env = "dev") {
    const id = `run_${Math.random().toString(36).slice(2, 8)}`;
    const steps = [
      { name: "Checkout", status: "ok" },
      { name: "tflint/tfsec", status: "ok" },
      { name: "Terraform Plan", status: "ok" },
      { name: env === "prod" ? "Manual Approval" : "Auto Gate", status: env === "prod" ? "waiting" : "ok" },
      { name: "Apply", status: env === "prod" ? "skipped" : "ok" },
      { name: "Invalidate CloudFront", status: env === "prod" ? "skipped" : "ok" }
    ];
    setCiRuns((prev) => [{ id, env, time: now(), steps }, ...prev].slice(0, 10));
  }

  // OU Explorer data
  const orgTree = useMemo(() => ([
    {
      id: "foundational",
      name: "Foundational OU",
      accounts: ["Log-Archive", "Security", "Networking"],
      scps: ["RequireTLS", "DenyRootActions", "RegionAllowlist"]
    },
    {
      id: "workloads",
      name: "Workloads OU",
      accounts: ["Prod", "Nonprod"],
      scps: ["MandatoryEncryption", "GuardrailForVPCe", "DenyPublicS3Write"]
    },
    {
      id: "sandboxes",
      name: "Sandboxes OU",
      accounts: ["Student-Labs"],
      scps: ["DisableExpensiveUnapproved", "RegionAllowlist"]
    },
    {
      id: "vendors",
      name: "Third-Party OU",
      accounts: ["Vendor-Integrations"],
      scps: ["ExternalIdRequired", "DenyPublicS3Write"]
    }
  ]), []);

  function Toggle({ checked, onChange }) {
    return (
      <button
        onClick={onChange}
        className={`w-10 h-6 rounded-full transition-colors ${checked ? "bg-green-500" : "bg-gray-400"}`}
        role="switch"
        aria-checked={checked}
      >
        <span className={`block w-5 h-5 bg-white rounded-full transform transition-transform ${checked ? "translate-x-4" : "translate-x-1"}`} />
      </button>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      {/* Top Nav */}
      <header className="sticky top-0 z-20 bg-slate-900/80 backdrop-blur border-b border-slate-800">
        <div className="mx-auto max-w-7xl px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-emerald-500 rounded-xl grid place-items-center font-bold text-slate-900">SC</div>
            <h1 className="text-lg font-semibold tracking-tight">SchoolCloud Secure Org</h1>
          </div>
          <nav className="flex gap-2 text-sm">
            {[
              ["overview", "Overview"],
              ["architecture", "Architecture"],
              ["identity", "Identity"],
              ["cicd", "CI/CD"],
              ["security", "Security"],
              ["simulate", "Simulate"],
              ["ai", "AI"],
              ["runbooks", "Runbooks"]
            ].map(([key, label]) => (
              <button
                key={key}
                onClick={() => setActiveTab(key)}
                className={`px-3 py-1 rounded-xl ${activeTab === key ? "bg-slate-800 text-emerald-400" : "hover:bg-slate-800/50"}`}
              >{label}</button>
            ))}
          </nav>
        </div>
      </header>

      {/* Content */}
      <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
        {activeTab === "overview" && <Overview onTriggerDemo={() => setActiveTab("simulate")} />}
        {activeTab === "architecture" && (
          <Architecture orgTree={orgTree} expandedNodes={expandedNodes} setExpandedNodes={setExpandedNodes} />
        )}
        {activeTab === "identity" && (
          <Identity
            policyView={policyView}
            setPolicyView={setPolicyView}
            token={token}
            signupForm={signupForm}
            setSignupForm={setSignupForm}
            loginForm={loginForm}
            setLoginForm={setLoginForm}
            doSignup={doSignup}
            doLogin={doLogin}
            setEncryption={setEncryption}
            addToGroup={addToGroup}
            ActivityFeed={ActivityFeed}
         />
        )}

        {activeTab === "cicd" && (
          <CiCd ciRuns={ciRuns} triggerCiRun={triggerCiRun} />
        )}
        {activeTab === "security" && (
          <SecurityPanel events={events} />
        )}
        {activeTab === "simulate" && (
          <Simulate onSimulate={simulate} events={events} />
        )}
        {activeTab === "ai" && <AiInsights events={events} />}
        {activeTab === "runbooks" && <Runbooks />}
      </main>

      <footer className="border-t border-slate-800/80 py-6 text-center text-xs text-slate-400">
        Built with Terraform + AWS + GitHub Actions + Splunk · Demo data only · © {new Date().getFullYear()} SchoolCloud
      </footer>
    </div>
  );
}

function Card({ title, children, className = "" }) {
  return (
    <div className={`rounded-2xl border border-slate-800 bg-slate-900/60 shadow-lg shadow-black/30 ${className}`}>
      <div className="px-5 py-4 border-b border-slate-800/80 flex items-center justify-between">
        <h3 className="text-sm font-semibold tracking-wide text-slate-200">{title}</h3>
      </div>
      <div className="p-5">{children}</div>
    </div>
  );
}

function Pill({ children }) {
  return <span className="px-2 py-0.5 rounded-full bg-slate-800 text-xs text-slate-300 border border-slate-700">{children}</span>;
}

// ---- Sections ----
function Overview({ onTriggerDemo }) {
  return (
    <div className="grid md:grid-cols-2 gap-6">
      <Card title="What is this?">
        <p className="text-sm text-slate-300 leading-relaxed">
          A live, school-inspired AWS Organization showing strong cloud security architecture: OUs & SCPs, permission boundaries,
          secure networking, IaC with Terraform, CI/CD via GitHub Actions (OIDC), and centralized observability in Splunk.
        </p>
        <div className="mt-4 flex gap-2 flex-wrap">
          <Pill>Organizations</Pill>
          <Pill>SCPs</Pill>
          <Pill>Permission Boundaries</Pill>
          <Pill>CloudFront + WAF</Pill>
          <Pill>Cognito</Pill>
          <Pill>API Gateway + Lambda</Pill>
          <Pill>DynamoDB</Pill>
          <Pill>VPC Endpoints</Pill>
          <Pill>GuardDuty</Pill>
          <Pill>Security Hub</Pill>
          <Pill>Splunk</Pill>
          <Pill>SageMaker (optional)</Pill>
        </div>
        <div className="mt-6 flex gap-3">
          <button onClick={onTriggerDemo} className="px-4 py-2 rounded-xl bg-emerald-500 text-slate-900 font-semibold hover:opacity-90">Simulate a Control</button>
          <a href="#" className="px-4 py-2 rounded-xl border border-slate-700 hover:bg-slate-800">View Architecture</a>
        </div>
      </Card>
      <Card title="Live Status (Demo)">
        <ul className="text-sm space-y-2">
          <li>CloudFront (OAC): <span className="text-emerald-400 font-semibold">Healthy</span></li>
          <li>WAF Managed Rules: <span className="text-emerald-400 font-semibold">Active</span></li>
          <li>GuardDuty & Security Hub: <span className="text-emerald-400 font-semibold">Enabled</span></li>
          <li>CI/CD (Actions OIDC): <span className="text-emerald-400 font-semibold">Configured</span></li>
        </ul>
        <div className="mt-4 text-xs text-slate-400">
          Tip: Replace with real health checks via a public status Lambda behind API Gateway.
        </div>
      </Card>
    </div>
  );
}

function Architecture({ orgTree, expandedNodes, setExpandedNodes }) {
  return (
    <div className="grid lg:grid-cols-2 gap-6">
      <Card title="Organization Explorer">
        <div className="space-y-3">
          {orgTree.map((node) => (
            <div key={node.id} className="border border-slate-800 rounded-xl overflow-hidden">
              <div className="flex items-center justify-between px-4 py-2 bg-slate-900">
                <div className="font-semibold">{node.name}</div>
                <button
                  onClick={() => setExpandedNodes({ ...expandedNodes, [node.id]: !expandedNodes[node.id] })}
                  className="text-xs px-2 py-1 rounded bg-slate-800"
                >{expandedNodes[node.id] ? "Collapse" : "Expand"}</button>
              </div>
              {expandedNodes[node.id] && (
                <div className="p-4 grid md:grid-cols-2 gap-3 text-sm">
                  <div>
                    <div className="text-slate-400 mb-1">Accounts</div>
                    <ul className="list-disc ml-5">
                      {node.accounts.map((a) => <li key={a}>{a}</li>)}
                    </ul>
                  </div>
                  <div>
                    <div className="text-slate-400 mb-1">Attached SCPs</div>
                    <ul className="list-disc ml-5">
                      {node.scps.map((s) => <li key={s}>{s}</li>)}
                    </ul>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      </Card>
      <Card title="Edge & Network (Conceptual)">
        <div className="text-sm text-slate-300 space-y-2">
          <p>Route53 → CloudFront (OAC) → WAF → S3 (static) & API Gateway → Lambda (private subnets with VPC endpoints).</p>
          <p>Logs: CloudTrail, WAF, VPC Flow Logs, API logs → S3/Kinesis Firehose → Splunk HEC.</p>
          <div className="mt-3 grid grid-cols-3 gap-2 text-center">
            <div className="p-3 bg-slate-800 rounded-xl">CloudFront + WAF</div>
            <div className="p-3 bg-slate-800 rounded-xl">API Gateway</div>
            <div className="p-3 bg-slate-800 rounded-xl">Lambda</div>
            <div className="p-3 bg-slate-800 rounded-xl">VPC Endpoints</div>
            <div className="p-3 bg-slate-800 rounded-xl">DynamoDB (KMS)</div>
            <div className="p-3 bg-slate-800 rounded-xl">Splunk (HEC)</div>
          </div>
        </div>
      </Card>
    </div>
  );
}

function Identity({
  policyView, setPolicyView,
  token,
  signupForm, setSignupForm,
  loginForm, setLoginForm,
  doSignup, doLogin,
  setEncryption, addToGroup,
  ActivityFeed
}) {
  const boundaryJson = `{
  "Version": "2012-10-17",
  "Statement": [
    {"Sid":"NoPrivilegeEscalation","Effect":"Deny","Action":["iam:CreatePolicyVersion","iam:SetDefaultPolicyVersion","iam:PassRole"],"Resource":"*"},
    {"Sid":"TagGuard","Effect":"Deny","Action":"*","Resource":"*","Condition":{"StringNotEquals":{"aws:ResourceTag/Project":"SchoolCloud"}}},
    {"Sid":"KMSRestricted","Effect":"Deny","Action":["kms:*"] ,"Resource":"*","Condition":{"StringNotEquals":{"kms:ResourceAliases":"alias/schoolcloud/*"}}}
  ]
}`;

  const ssoMarkdown = `Admins → limited-admin role (boundary enforced)
Faculty → read dashboards
Counselors → protected APIs (JWT group claims)
Students → sandbox only + budgets`;

  return (
    <div className="space-y-6">
      {/* Live Identity UI */}
      <div className="grid md:grid-cols-2 gap-6">
        {/* Left column: Signup / Login / Policies */}
        <div className="space-y-6">
          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 shadow-lg shadow-black/30">
            <div className="px-5 py-4 border-b border-slate-800/80">
              <h3 className="text-sm font-semibold tracking-wide text-slate-200">Create Demo Account</h3>
            </div>
            <div className="p-5">
              <form className="grid grid-cols-2 gap-3" onSubmit={doSignup}>
                <input className="col-span-2 px-3 py-2 rounded-xl bg-slate-800 border border-slate-700 text-sm"
                  placeholder="Email (fake ok)"
                  value={signupForm.email}
                  onChange={e => setSignupForm(f => ({ ...f, email: e.target.value }))} />
                <input className="col-span-2 px-3 py-2 rounded-xl bg-slate-800 border border-slate-700 text-sm"
                  placeholder="Password" type="password"
                  value={signupForm.password}
                  onChange={e => setSignupForm(f => ({ ...f, password: e.target.value }))} />
                <select className="px-3 py-2 rounded-xl bg-slate-800 border border-slate-700 text-sm"
                  value={signupForm.role}
                  onChange={e => setSignupForm(f => ({ ...f, role: e.target.value }))}>
                  <option value="student">Student</option>
                  <option value="teacher">Teacher</option>
                  <option value="admin">Admin</option>
                </select>
                <input className="px-3 py-2 rounded-xl bg-slate-800 border border-slate-700 text-sm"
                  placeholder="School ID (e.g., SCH-0001)"
                  value={signupForm.school_id}
                  onChange={e => setSignupForm(f => ({ ...f, school_id: e.target.value }))} />
                <input className="px-3 py-2 rounded-xl bg-slate-800 border border-slate-700 text-sm"
                  placeholder="DOB (YYYY-MM-DD)"
                  value={signupForm.dob}
                  onChange={e => setSignupForm(f => ({ ...f, dob: e.target.value }))} />
                <button className="col-span-2 px-4 py-2 rounded-xl bg-emerald-500 text-slate-900 font-semibold hover:opacity-90">
                  Sign up
                </button>
              </form>
              <p className="text-xs text-amber-400 mt-2">Demo only — do not use real personal data.</p>
            </div>
          </div>

          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 shadow-lg shadow-black/30">
            <div className="px-5 py-4 border-b border-slate-800/80">
              <h3 className="text-sm font-semibold tracking-wide text-slate-200">Login</h3>
            </div>
            <div className="p-5">
              <form className="grid grid-cols-2 gap-3" onSubmit={doLogin}>
                <input className="col-span-2 px-3 py-2 rounded-xl bg-slate-800 border border-slate-700 text-sm"
                  placeholder="Email"
                  value={loginForm.email}
                  onChange={e => setLoginForm(f => ({ ...f, email: e.target.value }))} />
                <input className="col-span-2 px-3 py-2 rounded-xl bg-slate-800 border border-slate-700 text-sm"
                  placeholder="Password" type="password"
                  value={loginForm.password}
                  onChange={e => setLoginForm(f => ({ ...f, password: e.target.value }))} />
                <button className="col-span-2 px-4 py-2 rounded-xl bg-slate-700 hover:bg-slate-600">
                  Login
                </button>
              </form>
              {token ? <p className="text-xs text-emerald-400 mt-2">Logged in</p> : null}
            </div>
          </div>

          <div className="rounded-2xl border border-slate-800 bg-slate-900/60 shadow-lg shadow-black/30">
            <div className="px-5 py-4 border-b border-slate-800/80">
              <h3 className="text-sm font-semibold tracking-wide text-slate-200">Policies &amp; Groups (demo)</h3>
            </div>
            <div className="p-5">
              <div className="flex flex-wrap gap-2">
                <button className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700" onClick={() => setEncryption("SSE-S3")} disabled={!token}>Set Encryption: SSE-S3</button>
                <button className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700" onClick={() => setEncryption("SSE-KMS")} disabled={!token}>Set Encryption: SSE-KMS</button>
                <button className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700" onClick={() => addToGroup("student")} disabled={!token}>Add to Student</button>
                <button className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700" onClick={() => addToGroup("teacher")} disabled={!token}>Add to Teacher</button>
                <button className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700" onClick={() => addToGroup("admin")} disabled={!token}>Add to Admin</button>
              </div>
            </div>
          </div>
        </div>

        {/* Right column: Activity Feed */}
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 shadow-lg shadow-black/30">
          <div className="px-5 py-4 border-b border-slate-800/80">
            <h3 className="text-sm font-semibold tracking-wide text-slate-200">Activity Feed</h3>
          </div>
          <div className="p-5">
            <ActivityFeed />
          </div>
        </div>
      </div>

      {/* (Optional) Keep your existing static cards below */}
      <div className="grid lg:grid-cols-2 gap-6">
        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 shadow-lg shadow-black/30">
          <div className="px-5 py-4 border-b border-slate-800/80">
            <h3 className="text-sm font-semibold tracking-wide text-slate-200">Identity Center (SSO) Mappings</h3>
          </div>
          <div className="p-5">
            <pre className="text-xs bg-slate-800 rounded-xl p-4 overflow-auto whitespace-pre-wrap">{ssoMarkdown}</pre>
            <div className="mt-3 text-xs text-slate-400">Map groups → accounts via Permission Sets. Use ABAC tags for finer control.</div>
          </div>
        </div>

        <div className="rounded-2xl border border-slate-800 bg-slate-900/60 shadow-lg shadow-black/30">
          <div className="px-5 py-4 border-b border-slate-800/80 flex items-center justify-between">
            <h3 className="text-sm font-semibold tracking-wide text-slate-200">Permission Boundary</h3>
            <div className="flex gap-2 text-xs">
              <button onClick={() => setPolicyView("boundary")} className={`px-3 py-1 rounded ${policyView==='boundary'?'bg-emerald-500 text-slate-900':'bg-slate-800'}`}>Boundary JSON</button>
              <button onClick={() => setPolicyView("explain")} className={`px-3 py-1 rounded ${policyView==='explain'?'bg-emerald-500 text-slate-900':'bg-slate-800'}`}>Explanation</button>
            </div>
          </div>
          <div className="p-5">
            {policyView === "boundary" ? (
              <pre className="text-xs bg-slate-800 rounded-xl p-4 overflow-auto">{boundaryJson}</pre>
            ) : (
              <ul className="text-sm list-disc ml-5 space-y-2">
                <li>Prevents privilege escalation (policy version, passrole abuse).</li>
                <li>Enforces project tagging for create/update/delete actions.</li>
                <li>Restricts KMS operations to approved aliases.</li>
              </ul>
            )}
            <div className="mt-3 text-xs text-slate-400">Attach this boundary to all human & automation roles (including OIDC deploy roles).</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function CiCd({ ciRuns, triggerCiRun }) {
  return (
    <div className="grid lg:grid-cols-2 gap-6">
      <Card title="Trigger a Pipeline (Demo)">
        <div className="flex gap-2 mb-4">
          <button onClick={() => triggerCiRun("dev")} className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700">Run DEV</button>
          <button onClick={() => triggerCiRun("stage")} className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700">Run STAGE</button>
          <button onClick={() => triggerCiRun("prod")} className="px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700">Prepare PROD</button>
        </div>
        <p className="text-xs text-slate-400">Wire these buttons to a GitHub Actions <code>workflow_dispatch</code> endpoint or a small API that calls the GitHub API.</p>
      </Card>
      <Card title="Recent CI/CD Runs">
        <div className="space-y-4">
          {ciRuns.length === 0 && <div className="text-sm text-slate-400">No runs yet. Trigger one on the left.</div>}
          {ciRuns.map((run) => (
            <div key={run.id} className="border border-slate-800 rounded-xl">
              <div className="px-4 py-2 bg-slate-900 text-sm flex justify-between">
                <div>
                  <span className="font-mono">{run.id}</span> · <span className="uppercase">{run.env}</span>
                </div>
                <div className="text-slate-400">{run.time}</div>
              </div>
              <div className="p-4 text-sm space-y-2">
                {run.steps.map((s, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <div className={`w-2 h-2 rounded-full ${s.status === 'ok' ? 'bg-emerald-400' : s.status === 'waiting' ? 'bg-amber-400' : 'bg-slate-600'}`} />
                    <div>{s.name}</div>
                    <div className="ml-auto text-xs text-slate-400">{s.status}</div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

function SecurityPanel({ events }) {
  const blocked = events.filter(e => e.status === "BLOCKED").length;
  const rolledBack = events.filter(e => e.status === "ROLLED_BACK").length;

  return (
    <div className="grid lg:grid-cols-3 gap-6">
      <Card title="At-a-glance">
        <div className="grid grid-cols-2 gap-4 text-center">
          <div className="p-3 bg-slate-800 rounded-xl">
            <div className="text-2xl font-bold text-emerald-400">{blocked}</div>
            <div className="text-xs text-slate-400">Controls Blocked</div>
          </div>
          <div className="p-3 bg-slate-800 rounded-xl">
            <div className="text-2xl font-bold text-amber-400">{rolledBack}</div>
            <div className="text-xs text-slate-400">Auto Rollbacks</div>
          </div>
        </div>
        <div className="mt-4 text-xs text-slate-400">Replace with live Splunk panels via images or public embeds.</div>
      </Card>
      <Card title="Recent Security Events" className="lg:col-span-2">
        <EventTable events={events} />
      </Card>
    </div>
  );
}

function Simulate({ onSimulate, events }) {
  return (
    <div className="grid lg:grid-cols-3 gap-6">
      <Card title="Simulation Controls">
        <div className="grid gap-2">
          <button onClick={() => onSimulate("scp-deny")} className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-left">🧱 Trigger SCP Deny</button>
          <button onClick={() => onSimulate("waf-block")} className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-left">🌐 Cause WAF Block</button>
          <button onClick={() => onSimulate("unencrypted-put")} className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-left">🔐 Unencrypted S3 PUT Test</button>
          <button onClick={() => onSimulate("login-anomaly")} className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-left">🕵️ Login Anomaly</button>
          <button onClick={() => onSimulate("deploy-bad-canary")} className="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-left">🚦 Deploy Bad Canary</button>
        </div>
        <div className="mt-4 text-xs text-slate-400">
          Wire each button to an API Gateway endpoint backed by a constrained Lambda that safely triggers the event and logs to Splunk.
        </div>
      </Card>
      <Card title="Event Log" className="lg:col-span-2">
        <EventTable events={events} />
      </Card>
    </div>
  );
}

function EventTable({ events }) {
  return (
    <div className="overflow-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="text-left text-slate-400 border-b border-slate-800">
            <th className="py-2 pr-4">Time</th>
            <th className="py-2 pr-4">Action</th>
            <th className="py-2 pr-4">Status</th>
            <th className="py-2 pr-4">Detail</th>
            <th className="py-2 pr-4">Event Id</th>
          </tr>
        </thead>
        <tbody>
          {events.length === 0 ? (
            <tr><td colSpan={5} className="py-6 text-center text-slate-500">No events yet. Use the simulation controls to generate some.</td></tr>
          ) : (
            events.map((e) => (
              <tr key={e.id} className="border-b border-slate-800/60">
                <td className="py-2 pr-4 whitespace-nowrap">{e.time}</td>
                <td className="py-2 pr-4 font-mono">{e.action}</td>
                <td className="py-2 pr-4">
                  <span className={`px-2 py-0.5 rounded-full text-xs ${e.status === 'BLOCKED' ? 'bg-emerald-500 text-slate-900' : 'bg-amber-400 text-slate-900'}`}>{e.status}</span>
                </td>
                <td className="py-2 pr-4">{e.detail}</td>
                <td className="py-2 pr-4 font-mono">{e.id}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

function AiInsights({ events }) {
  const aiRows = events.filter(e => e.action === "login-anomaly").map((e) => ({
    time: e.time,
    score: (Math.random() * 0.6 + 0.4).toFixed(2),
    type: "After-hours login anomaly",
    id: e.id
  }));

  return (
    <div className="grid lg:grid-cols-2 gap-6">
      <Card title="How it works">
        <ol className="list-decimal ml-5 text-sm space-y-2">
          <li>Logs land in S3/Kinesis (CloudTrail, VPC Flow, Cognito).</li>
          <li>SageMaker endpoint scores events (RCF/XGBoost).</li>
          <li>Lambda creates a custom Security Hub finding for high scores.</li>
          <li>EventBridge routes findings to Splunk and notifies on-call.</li>
        </ol>
        <div className="mt-3 text-xs text-slate-400">Swap this text for a real diagram or notebook links.</div>
      </Card>
      <Card title="Recent AI Flags (Demo)">
        <div className="overflow-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-400 border-b border-slate-800">
                <th className="py-2 pr-4">Time</th>
                <th className="py-2 pr-4">Score</th>
                <th className="py-2 pr-4">Type</th>
                <th className="py-2 pr-4">Event Id</th>
              </tr>
            </thead>
            <tbody>
              {aiRows.length === 0 ? (
                <tr><td colSpan={4} className="py-6 text-center text-slate-500">No AI flags yet. Trigger a Login Anomaly from Simulate.</td></tr>
              ) : (
                aiRows.map((r) => (
                  <tr key={r.id} className="border-b border-slate-800/60">
                    <td className="py-2 pr-4 whitespace-nowrap">{r.time}</td>
                    <td className="py-2 pr-4 font-mono">{r.score}</td>
                    <td className="py-2 pr-4">{r.type}</td>
                    <td className="py-2 pr-4 font-mono">{r.id}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}

function Runbooks() {
  return (
    <div className="grid lg:grid-cols-2 gap-6">
      <Card title="SCP Deny Triage">
        <ol className="list-decimal ml-5 text-sm space-y-2">
          <li>Identify the principal & requested action in CloudTrail.</li>
          <li>Confirm which SCP or Permission Boundary blocked it.</li>
          <li>If legitimate, propose a least-privilege change via PR (Terraform).</li>
          <li>Re-run CI/CD with approvals; document in change log.</li>
        </ol>
      </Card>
      <Card title="Prod Rollback (Blue/Green/Canary)">
        <ol className="list-decimal ml-5 text-sm space-y-2">
          <li>Flip Lambda alias back to previous version on failed canary.</li>
          <li>Revert ECS service to prior task definition revision.</li>
          <li>Create incident ticket; attach logs/metrics and postmortem tasks.</li>
        </ol>
      </Card>
    </div>
  );
}
