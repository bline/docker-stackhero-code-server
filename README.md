# code-server Deployment to Fly.io

This project simplifies deploying [code-server](https://github.com/coder/code-server) (VS Code in the browser) to [Fly.io](https://fly.io). Configure your instance via a `.env` file, set secure secrets, and deploy with ease. Includes Git integration, SSH key setup, and a customizable shell environment.

## Features

- **Secure Authentication**: Enforces password protection via Fly.io secrets.
- **GitHub Integration**: Use a `GITHUB_TOKEN` secret for enhanced extension management.
- **Persistent Workspace**: Mounted volume for your code and configurations.
- **Customizable Environment**: Pre-configured `.bashrc` with aliases, Git tools, and prompts.
- **Auto-Sleep**: Save resources with configurable idle timeout and VM auto-stop.

---

## Prerequisites

- [Fly.io account](https://fly.io/docs/getting-started/signing-up/)
- [Fly CLI installed](https://fly.io/docs/hands-on/install-flyctl/)
- Docker (for local testing, optional)

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/bline/fly-code-server.git
cd fly-code-server
```

### 2. Configure Environment

Copy the example environment file and update values:
```bash
cp .env-example .env
nano .env  # Edit variables (see Configuration section below)
```

### 3. Set Fly.io Secrets

Required Secrets (run these commands before deployment):

```bash
flyctl secrets set PASSWORD=your_strong_password_here
flyctl secrets set GITHUB_TOKEN=your_github_personal_access_token  # Optional but recommended
```

### 4. Build & Deploy

```bash
chmod +x build.sh  # Make the script executable
./build.sh         # Generates fly.toml from your .env
flyctl deploy      # Deploy to Fly.io
```

---

## Configuration

### .env File Variables

| Variable               | Description                                                |
|------------------------|------------------------------------------------------------|
| `PROJECT_NAME`         | The name of your project on fly.io (e.g. my-code-server)   |
| `CODE_SERVER_VERSION`  | Version of code-server (default: latest). Example: 4.96.4. |
| `GIT_USER`/`GIT_EMAIL` | Git global configuration (required for commits).           |
| `TZ`                   | Timezone (e.g., America/New_York).                         |
| `DEFAULT_WORKSPACE`    | Persistent storage directory (default: /workspace).        |
| `IDLE_TIMEOUT`         | Seconds before VM sleeps (max 900).                        |
| `AUTO_STOP_MACHINE`    | VM behavior on idle: stop, suspend, or off.                |
| `VM_SIZE`              | The VM size on fly.io (e.g. shared-cpu-2x)                 |
| `VM_MEMORY`            | The VM memory setting (e.g. 2gb)                           |

### Fly.io Secrets

- `PASSWORD`: Required. Password to access your code-server instance.
- `GITHUB_TOKEN`: Optional but recommended for GitHub authentication in extensions.

Set secrets via:

```bash
flyctl secrets set NAME=value
```

---

## Accessing Your Instance

After deployment:

1. Visit your Fly.io app URL (e.g., `https://$PROJECT_NAME.fly.dev`).

2. Log in with the password set in the `PASSWORD` secret.

---

## Customization

- **Shell Environment**: Modify `bashrc` to add aliases, functions, or prompt changes.

- **VM Resources**: Adjust `VM_SIZE` and `VM_MEMORY` in .env for more CPU/RAM.

- **Code-Server Version**: Specify `CODE_SERVER_VERSION` in .env to pin a version of code-server.

---

## Troubleshooting

- **"Invalid Password"**: Ensure `PASSWORD` is set as a Fly secret, not in .env.

- **Build Failures**: Verify all `.env` variables are set and paths are correct.

- **VM Not Starting**: Check `flyclt logs`. You need more memory than the default fly settings gives (1gb) to run code-server.

---

## Notes

- **Data Persistence**: Your workspace is stored in a Fly volume named `code_workspace`.

- **SSH Keys**: Generated automatically at `${DEFAULT_WORKSPACE}/.ssh/id_rsa`.

- **Git Configuration**: Set `GIT_USER` and `GIT_EMAIL` in `.env` to avoid warnings.

---

## 🚀 Happy Coding!

Your instance is ready for development. Clone repos, install extensions, and code from anywhere!
