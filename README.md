# code-server Deployment to Fly.io

This project simplifies deploying [code-server](https://github.com/coder/code-server) (VS Code in the browser) to [Fly.io](https://fly.io). Configure your instance via a `fly.toml` file, set secure secrets, and deploy with ease. Includes Git integration, SSH key setup, and a customizable shell environment.

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
cp fly-example.toml fly.toml
nano fly.toml  # Edit variables (see Configuration section below)
```

### 3. Set Fly.io Secrets

Required Secrets (run these commands before deployment):

```bash
flyctl secrets set PASSWORD=your_strong_password_here
flyctl secrets set GITHUB_TOKEN=your_github_personal_access_token  # Optional but recommended
```

### 4. Deploy

#### Deploy to fly.io

```bash
flyctl deploy      # Deploy to Fly.io
```

#### Or run locally

To run locally, you need `docker` installed.

```bash
export CODE_SERVER_PASSWORD="code-server-password"
export GITHUB_TOKEN="github token"
./run_local.sh
```

If you do not set `CODE_SERVER_PASSWORD` or `GITHUB_TOKEN`, `run_local.sh` will prompt for them.

---

## Configuration

### Dockerfile arguments in `build.args` in `fly.toml`

| Variable             | Description                                                                                                         |
| ---------------------| ------------------------------------------------------------------------------------------------------------------- |
| `BUILD_DATE`         | The date when the image was built (default: `"2025-02-05"`).                                                        |
| `CODE_RELEASE`       | Version of code-server to install (default: `"latest"`). Example: `"4.96.4"`.                                       |
| `DEFAULT_WORKSPACE`  | Persistent storage directory (default: `"/workspace"`).                                                             |
| `SERVER_PORT`        | The internal port code-server listens on (default: `"8080"`).                                                       |
| `USER_NAME`          | The user to run code-server as (default: `"coder"`).                                                                |
| `USER_SHELL`         | The shell assigned to the user (default: `"/bin/bash"`).                                                            |
| `INSTALL_NODE`       | If `"true"`, installs Node.js from [NodeSource](https://github.com/nodesource/distributions).                       |
| `NODE_MAJOR_VERSION` | Major version of Node.js to install if `INSTALL_NODE="true"` (e.g., `"22"`).                                        |
| `INSTALL_CST`        | If `"true"`, installs [Container Structure Test](https://github.com/GoogleContainerTools/container-structure-test). |
| `CST_VERSION`        | Version of Container Structure Test to install (e.g., `"latest"`).                                                  |
| `INSTALL_HADOLINT`   | If `"true"`, installs [Hadolint](https://github.com/hadolint/hadolint) for Dockerfile linting.                      |
| `HADOLINT_VERSION`   | Version of Hadolint to install (e.g., `"v2.12.0"`).                                                                 |
| `INSTALL_RUST`       | If `"true"`, installs Rust system-wide in `/opt/rust`.                                                              |
| `RUST_VERSION`       | Version of Rust to install (e.g., `"1.84.1"`).                                                                      |
| `RUST_PACKAGES`      | Space-separated list of Rust Cargo packages to install globally.<br> **Crates.io packages:** Installed with `cargo install <package>`.<br> **GitHub packages:** Installed with `cargo install --git <repo>`. |


### Fly.io Secrets

- `PASSWORD`: Required. Password to access your code-server instance.
- `GITHUB_TOKEN`: Optional but recommended for GitHub authentication in extensions.

To set secrets in Fly.io, run:

```bash
flyctl secrets set PASSWORD="your_strong_password_here"
flyctl secrets set GITHUB_TOKEN="your_github_token_here"
```

---

## Running as `coder`

By default, this deployment runs `code-server` as the user `coder` instead of `root`. This ensures consistency with tools in the environment and configuration across deployments. The home directory for `coder` is set to `$DEFAULT_WORKSPACE`.

Additionally, the `coder` user has passwordless `sudo` access to simplify maintenance commands.

To verify the user inside the running instance:

```bash
whoami  # Should output 'coder'
echo $HOME  # Should output the DEFAULT_WORKSPACE path
```

To run privileged commands:

```bash
sudo <command>
```

---

## Accessing Your Instance

After deployment:

1. Visit your Fly.io app URL (e.g., `https://<app>.fly.dev`).
2. Log in with the password set in the `PASSWORD` secret.

---

## Customization

- **Shell Environment**: Modify `bashrc` to add aliases, functions, or prompt changes.
- **VM Resources**: Adjust `vm.size` and `vm.memory` in `fly.toml` for more CPU/RAM.
- **Code-Server Version**: Specify `CODE_RELEASE` in `fly.toml` to pin a version of code-server.

---

## Troubleshooting

- **"Invalid Password"**: Ensure `PASSWORD` is set as a Fly secret, not in fly.toml.
- **Build Failures**: Verify all `fly.toml` variables are set and paths are correct.
- **VM Not Starting**: Check `flyctl logs`. If using `shared-cpu-1x` (1GB RAM), consider increasing to `shared-cpu-2x` (2GB) in `fly.toml`.

---

## Notes

- **Data Persistence**: Your workspace is stored in a Fly volume named `code_workspace`.
- **SSH Keys**: Generated automatically at `${DEFAULT_WORKSPACE}/.ssh/id_rsa`.
- **Git Configuration**: Set `GIT_USER` and `GIT_EMAIL` in `fly.toml` to configure `git`.

---

## 🚀 Happy Coding!

Your instance is ready for development. Clone repos, install extensions, and code from anywhere!
