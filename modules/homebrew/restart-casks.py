import json
import os
import plistlib
import subprocess
import sys
import time

APP_DIR = "/Applications"
YELLOW = "\033[1;33m{}\033[0m"


def warn(message):
    print(YELLOW.format(message), file=sys.stderr)


def as_user(user, *command):
    uid = subprocess.run(["/usr/bin/id", "-u", "--", user], check=True, capture_output=True, text=True).stdout.strip()
    return ["/bin/launchctl", "asuser", uid, "/usr/bin/sudo", f"--user={user}", "--set-home", "--", *command]


def brew(brew_path, user, *args):
    command = ["/usr/bin/sudo", f"--user={user}", "--set-home", "/usr/bin/env", "HOMEBREW_NO_AUTO_UPDATE=1", brew_path, *args]
    return subprocess.run(command, check=True, capture_output=True, text=True, cwd="/").stdout


def cask_versions(brew_path, user):
    versions = {}
    for line in brew(brew_path, user, "list", "--cask", "--versions").splitlines():
        token, _, version = line.partition(" ")
        versions[token] = version
    return versions


def processes():
    """Return (pid, ppid, executable path) for every process."""
    output = subprocess.run(["/bin/ps", "-axo", "pid=,ppid=,comm="], check=True, capture_output=True, text=True).stdout
    rows = []
    for line in output.splitlines():
        fields = line.split(None, 2)
        if len(fields) == 3:
            rows.append((int(fields[0]), int(fields[1]), fields[2]))
    return rows


def main_pids(executable, rows):
    return {pid for pid, _, path in rows if path == executable}


def ancestors(rows):
    parents = {pid: ppid for pid, ppid, _ in rows}
    pid = os.getpid()
    seen = set()
    while pid > 1 and pid not in seen:
        seen.add(pid)
        pid = parents.get(pid, 1)
    return seen


def app_paths(cask):
    # Each app stanza is ["Source.app"] or ["Source.app", {"target": "Name.app"}].
    for artifact in cask.get("artifacts", []):
        stanza = artifact.get("app", [])
        source = next((item for item in stanza if isinstance(item, str)), None)
        if source is None:
            continue
        options = next((item for item in stanza if isinstance(item, dict)), {})
        target = options.get("target", os.path.basename(source))
        yield target if os.path.isabs(target) else os.path.join(APP_DIR, target)


def snapshot(state_path, brew_path, user):
    state = {
        "versions": cask_versions(brew_path, user),
        "running": [[pid, path] for pid, _, path in processes()],
    }
    with open(state_path, "w") as file:
        json.dump(state, file)


def restart_app(app, running, user):
    name = os.path.basename(app).removesuffix(".app")
    with open(f"{app}/Contents/Info.plist", "rb") as file:
        info = plistlib.load(file)
    # Other executables in Contents/MacOS, such as keepassxc-proxy, run without the app.
    executable = f"{app}/Contents/MacOS/{info['CFBundleExecutable']}"
    before = {pid for pid, path in running if path == executable}
    if not before:
        return

    rows = processes()
    current = main_pids(executable, rows)
    old = before & current
    if old & ancestors(rows):
        warn(f"Skipped restarting {name} after its upgrade because it runs this activation. Restart it to load the new version.")
        return
    if old:
        print(f"Restarting {name} to load its upgraded version.")
        quit_script = f'tell application id "{info["CFBundleIdentifier"]}" to quit'
        subprocess.run(as_user(user, "/usr/bin/osascript", "-e", quit_script), capture_output=True)
        deadline = time.monotonic() + 30
        while before & main_pids(executable, processes()) and time.monotonic() < deadline:
            time.sleep(0.5)
        if before & main_pids(executable, processes()):
            warn(
                f"Could not quit {name} after its upgrade. Quit it, or allow your terminal to control it under "
                "System Settings > Privacy & Security > Automation, and reopen it to load the new version."
            )
            return
    elif current:
        # It already relaunched on the new version.
        return
    else:
        # Homebrew quits apps whose casks declare it before replacing them.
        print(f"Reopening {name}, which Homebrew quit to upgrade it.")
    if subprocess.run(as_user(user, "/usr/bin/open", "-g", app)).returncode != 0:
        warn(f"Could not reopen {name} after its upgrade.")


def restart(state_path, brew_path, user):
    with open(state_path) as file:
        state = json.load(file)
    before = state["versions"]
    after = cask_versions(brew_path, user)
    upgraded = sorted(token for token, version in after.items() if token in before and before[token] != version)
    if not upgraded:
        return

    casks = json.loads(brew(brew_path, user, "info", "--cask", "--json=v2", *upgraded))["casks"]
    for cask in casks:
        for app in app_paths(cask):
            try:
                restart_app(app, state["running"], user)
            except Exception as error:
                warn(f"Could not restart {app} after its upgrade: {error}")


def main():
    mode, state_path, brew_path, user = sys.argv[1:]
    try:
        {"snapshot": snapshot, "restart": restart}[mode](state_path, brew_path, user)
    except Exception as error:
        warn(f"Could not {mode} running casks around brew bundle, so upgraded apps may need a manual restart: {error}")
        sys.exit(1)


main()
