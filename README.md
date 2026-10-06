# DevSecOps pipeline (learning project)

A tiny static website whose real purpose is the pipeline behind it. Every push goes
through code scanning, a container scan, a throwaway staging deploy, a live attack
with OWASP ZAP, and a security gate. Only if the gate passes does it reach GitHub Pages.

## How the flow maps to the workflow

| # | Stage | Job in `.github/workflows/devsecops.yml` | Tool |
|---|---|---|---|
| 1-2 | Write code, push | (you) | git |
| 3 | GitHub Actions starts | `on: push / pull_request` | GitHub Actions |
| 4 | Prepare environment | first steps of `code-scan` | checkout, setup-node, npm ci |
| 5 | Scan the code | `code-scan` | Gitleaks (secrets), Semgrep (SAST), npm audit (SCA) |
| 6 | Build | `build` | ESLint, `scripts/build.js`, Docker |
| 7 | Scan built container | `image-scan` | Trivy |
| 8 | Deploy to staging | `staging-dast` | Docker container inside the runner |
| 9 | Attack / test it | `staging-dast` | curl smoke test, OWASP ZAP baseline (DAST) |
| 10 | Collect findings | `security-gate` | downloads all `report-*` artifacts |
| 11 | Security decision | `security-gate` | `scripts/security-gate.sh` |
| PASS | Production | `deploy-production` | GitHub Pages |
| FAIL | Fix issues | `fix-issues` | opens a GitHub issue |

Scanners never fail on their own. They only write reports, and the gate makes one
decision from all of them. That keeps "find" separate from "decide", like real DevSecOps
setups do. Missing or unreadable reports also fail the gate, so a crashed scanner can't
sneak code through.

## Setup (about 5 minutes)

1. Create a new **public** repo on GitHub (for example `devsecops-demo`).
2. Copy these files in, then generate the lockfile and push:
   ```bash
   npm install          # creates package-lock.json (npm ci needs it)
   git init && git add . && git commit -m "first pipeline"
   git branch -M main
   git remote add origin https://github.com/<you>/devsecops-demo.git
   git push -u origin main
   ```
3. In the repo go to **Settings > Pages** and set **Source** to **GitHub Actions**.
4. Open the **Actions** tab and watch the run. When it passes, the site is at
   `https://<you>.github.io/devsecops-demo/`.

(If you name the repo `<you>.github.io`, it deploys to the root `https://<you>.github.io/`.)

The gate's results table appears on the run's summary page. Every report is downloadable
as the `all-security-findings` artifact.

## Run it locally

```bash
npm install
npm run lint
npm run build
docker build -t devsecops-demo . && docker run -p 8080:8080 devsecops-demo
# open http://localhost:8080
```

## Experiments: break it on purpose

Each one should turn the gate red and open an issue. Revert to go green again.

1. **Leak a secret.** Add a line like `const key = "AKIA` + `IOSFODNN7EXAMPLE";` (as one string)
   to `src/app.js`. Gitleaks catches it. Note: it stays in git history even after you delete it,
   which is exactly why secret scanning reads the full history.
2. **Write unsafe code.** In `src/app.js`, replace `textContent` with `innerHTML`, or add `eval(location.hash)`.
   Watch ESLint and Semgrep react.
3. **Add a vulnerable dependency.** `npm install lodash@4.17.15` and push. npm audit flags it.
4. **Use an old base image.** Change the Dockerfile to `FROM nginx:1.19` and watch Trivy's CVE count explode.
5. **Remove security headers.** Delete the `add_header` lines from `nginx.conf`. ZAP reports them as findings.
   (They're medium risk, so they show as non-blocking. Set `MAX_DAST_HIGH` logic to include mediums if you want them to block.)
6. **Tune the policy.** Change the limits at the top of `scripts/security-gate.sh`.

## Things worth knowing

- **Staging is ephemeral.** GitHub Pages hosts one site per repo, so staging runs as a
  container inside the runner and disappears after the job. Real teams often do the same with
  "review apps"; others use a separate server or cloud environment.
- **Headers differ between staging and production.** nginx sets real HTTP security headers
  in staging. GitHub Pages can't set custom headers, so production gets a CSP via a `<meta>` tag
  in `index.html`, which covers less (no `frame-ancestors`, for example).
- **Pull requests** run every scan but never deploy and never open issues.
- **Pin your actions.** For learning, actions are pinned to version tags. In production, pin them
  to a full commit SHA, since a compromised tag would run inside your pipeline.

## Next steps once this works

- Upload Semgrep and Trivy results as SARIF so they show up in the repo's **Security** tab.
- Add CodeQL for deeper code analysis.
- Generate an SBOM with Syft and attach it to the build.
- Add a manual approval rule on the `github-pages` environment (Settings > Environments)
  so a human signs off before production.
