import os
import sys
import signal
import time
import argparse
import textwrap
import platform
import subprocess

os.chdir(os.path.dirname(os.path.realpath(__file__)))
os.chdir("../..")
sys.dont_write_bytecode = True
sys.path.insert(0, 'lib')
import process_manager
received_signal = False
shutdown_functions = []

processes = process_manager.ProcessManager()

WELCOME_TEXT = 'RoMeLa Point Cloud Analyzer'


# Script locations.
DOCKER_RUN_ENV_SCRIPT   = "./tools/scripts/build_env/run_env.sh "
DOCKER_EXEC_SCRIPT      = "./tools/scripts/build_env/exec.sh "
DOCKER_EXEC_KILL_SCRIPT = "./tools/scripts/build_env/exec_kill.sh "
LINT_CHECK_SCRIPT = "./tools/scripts/lint/check_format.sh"
LINT_FORMAT_SCRIPT = "./tools/scripts/lint/format.sh"
DEPLOY_SCRIPT = "./tools/scripts/build_env/deploy.sh "

# Command chains.
if "CONTINUOUS_INTEGRATION" in os.environ \
        and os.environ["CONTINUOUS_INTEGRATION"] == "true":

    # Limit verbosity in CI logs.
    BAZEL_BUILD = "bazel build --noshow_progress "
    BAZEL_TEST = "bazel test --noshow_progress "
else:
    BAZEL_BUILD = "bazel build "
    BAZEL_TEST = "bazel test "

def print_update(message, msg_type="STATUS"):
    SPLIT_SIZE = 65

    msg_split = message.splitlines()

    lines = list()
    for line in msg_split:
        lines.extend(textwrap.wrap(line, SPLIT_SIZE, break_long_words=False))

    print("\n")
    for i in range(0, len(lines) + 2):
        if i > 0 and i < len(lines) + 1:
            line = lines[i - 1]
        else:
            line = ""

        other_stuff = (5 + len(line) + 5)
        padding_left = (80 - other_stuff) / 2
        padding_right = 80 - padding_left - other_stuff
        print_line = ""

        if msg_type is "STATUS":
            print_line += "\033[94m"
        if msg_type is "STATUS_LIGHT":
            print_line += "\033[96m"
        elif msg_type is "SUCCESS":
            print_line += "\033[92m"
        elif msg_type is "FAILURE":
            print_line += "\033[91m"

        print_line += "#### "
        print_line += " " * padding_left
        print_line += line
        print_line += " " * padding_right
        print_line += " ####\033[0m"

        print(print_line)


def signal_received(signal, frame):
    global received_signal
    if received_signal:
        print_update("ALREADY GOT SIGNAL RECEIVED ACTION! (be patient...)", \
                msg_type="FAILURE")
        return

    received_signal = True

    # Shutdown all the spawned processes and exit cleanly.
    print_update("performing signal received action...", msg_type="FAILURE")

    status = "Signal received (" + str(signal) + ") - killing all spawned " \
            "processes\n"

    global shutdown_functions
    shutdown_functions = set(shutdown_functions) # unique list
    for shutdown_function in shutdown_functions:
        status += shutdown_function()

    status += processes.killall()
    print_update(status, "FAILURE")
    sys.exit(0)


def kill_processes_in_build_env_container():
    if processes.spawn_process_wait_for_code(DOCKER_EXEC_KILL_SCRIPT) == 0:
        return "Killed all spawned processes in docker image.\n"
    return ""


def kill_docker_container(name):
    command = "docker kill $(docker ps " \
              "--filter status=running " \
              "--format \"{{.ID}}\" " \
              "--filter name="+name+" " \
              "--latest)"

    return processes.spawn_process_wait_for_code(command, show_output=False, allow_input=False)


def kill_build_env():
    if kill_docker_container("romela_build_env") == 0:
        return "Killed docker container\n"
    return ""


def run_and_die_if_error(command):
    if (processes.spawn_process_wait_for_code(command) != 0):
        processes.killall()
        sys.exit(1)


def run_cmd_exit_failure(cmd):
    if processes.spawn_process_wait_for_code(cmd, allow_input=False) > 0:
        status = "ERROR when running command: " + cmd + "\n" \
                "Killing all spawned processes\n"

        status += processes.killall()
        print_update(status, "FAILURE")

        sys.exit(1)


################################################################### Docker tools
def run_docker_start(args=None, show_complete=True):
    run_env(show_complete=False)

    if show_complete:
        print_update("Docker container started successfully", \
                msg_type="SUCCESS")


def run_docker_rebuild(args=None, show_complete=True):
    print_update("Rebuilding docker environment.")
    run_docker_kill(False)
    run_env(show_complete=False, rebuild=True)

    if show_complete:
        print_update("Docker container started successfully", \
                msg_type="SUCCESS")


def run_docker_kill(args=None, show_complete=True):
    result = kill_build_env()

    if show_complete:
        if result == "":
            print_update("Docker container didn't exist in the first place", \
                msg_type="FAILURE")
        else:
            print_update("Docker container killed successfully", \
                    msg_type="SUCCESS")


def run_docker_shell(args):
    # Make sure the controls docker image is running first.
    run_docker_start(None, show_complete=False)

    # Run interactive command line
    print_update("Starting shell tunnel to docker container")
    processes.run_command("./tools/scripts/build_env/exec_interactive.sh " \
        "/bin/bash")


def run_install(args=None):
    run_and_die_if_error("bash ./tools/scripts/install.sh")


def run_cleanup_docker(args):
    processes.spawn_process("./tools/scripts/docker/cleanup.sh")
    processes.wait_for_complete()
    print_update("Docker cleanup complete", "SUCCESS")


def run_travis(args):
    run_and_die_if_error("bazel build //src/...")
    run_and_die_if_error("bazel build --cpu=raspi //src/...")
    run_and_die_if_error("bazel build @PX4_sitl//:jmavsim")
    run_and_die_if_error("bazel test //src/...")
    run_and_die_if_error("bazel test //lib/...")
    run_and_die_if_error(
        "./bazel-out/k8-fastbuild/bin/src/controls/loops/flight_loop_lib_test")


def run_build(args=None, show_complete=True):
    shutdown_functions.append(kill_processes_in_build_env_container)

    run_build_env_docker_start(None, show_complete=False)

    print_update("Building code for AMD64...")
    run_cmd_exit_failure(DOCKER_EXEC_SCRIPT + BAZEL_BUILD + \
            " //src/... //lib/...")

    if show_complete:
        print_update("Build successful :^)", msg_type="SUCCESS")


def run_run(args=None, show_complete=True):
    run_build(show_complete=False)

    # processes.spawn_process("./tools/cache/bazel/execroot/com_romela/" \
    #         "bazel-out/k8-fastbuild/bin/src/display/display")

    processes.wait_for_complete()


def run_build_env_docker_start(args=None, show_complete=True):
    print_update("Making sure all the necessary packages are installed")

    # Start the software development docker image if it is not already
    # running.
    run_env(show_complete=False)

    if show_complete:
        print_update("\n\nControls docker container started successfully", \
                msg_type="SUCCESS")


def run_build_env_docker_rebuild(args=None, show_complete=True):
    print_update("Rebuilding docker environment.")
    run_build_env_docker_kill(False)

    # Start the development docker image if it is not already
    # running.
    run_env(show_complete=False, rebuild=True)

    if show_complete:
        print_update("\n\Docker container started successfully", \
                msg_type="SUCCESS")


def run_build_env_docker_kill(args=None, show_complete=True):
    result = kill_build_env()

    if show_complete:
        if result == "":
            print_update("\n\nDocker docker container was not running.", \
                    msg_type="FAILURE")
        else:
            print_update("\n\nControls docker container killed successfully", \
                    msg_type="SUCCESS")


def run_build_env_docker_shell(args):
    run_build_env_docker_start(None, show_complete=False)
    print_update("Create shell tunnel to docker container")
    processes.run_command("./tools/scripts/controls/exec_interactive.sh " \
            "/bin/bash")


def run_env(args=None, show_complete=True, rebuild=False):
    print_update("Starting development environment...")

    if rebuild:
        run_cmd_exit_failure(DOCKER_RUN_ENV_SCRIPT + " --rebuild")
    else:
        run_cmd_exit_failure(DOCKER_RUN_ENV_SCRIPT)

    if show_complete:
        print_update("Development environment started successfully!", \
            msg_type="SUCCESS")


def run_lint(args):
    print_update("Starting development environment...")
    run_cmd_exit_failure(DOCKER_RUN_ENV_SCRIPT)

    print_update("Running lint...")

    if args.format:
        print_update("Formatting the code...")
        run_cmd_exit_failure(LINT_FORMAT_SCRIPT)
        print_update("Format finished!", msg_type="SUCCESS")
    elif args.check:
        print_update("Checking lint...")
        run_cmd_exit_failure(LINT_CHECK_SCRIPT)
        print_update("Lint check passed!", msg_type="SUCCESS")
    else:
        print_update("NO LINTING OPTION SPECIFIED.", "FAILURE")


def run_vscode(args):
    run_cmd_exit_failure("code ./vscode.code-workspace")
    print_update("Started vscode!", msg_type="SUCCESS")


if __name__ == '__main__':
    signal.signal(signal.SIGINT, signal_received)

    print_update(WELCOME_TEXT, msg_type="STATUS_LIGHT")
    run_install()

    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    build_parser = subparsers.add_parser('build')
    build_parser.set_defaults(func=run_build)
    run_parser = subparsers.add_parser('run')
    run_parser.set_defaults(func=run_run)

    docker_parser = subparsers.add_parser('docker')
    docker_subparsers = docker_parser.add_subparsers()
    docker_start = docker_subparsers.add_parser('start')
    docker_start.set_defaults(func=run_docker_start)
    docker_rebuild = docker_subparsers.add_parser('rebuild')
    docker_rebuild.set_defaults(func=run_docker_rebuild)
    docker_kill = docker_subparsers.add_parser('kill')
    docker_kill.set_defaults(func=run_docker_kill)
    docker_shell = docker_subparsers.add_parser('shell')
    docker_shell.set_defaults(func=run_docker_shell)

    lint_parser = subparsers.add_parser('lint')
    lint_parser.set_defaults(func=run_lint)
    lint_parser.add_argument('--format', action='store_true')
    lint_parser.add_argument('--check', action='store_true')

    vscode_parser = subparsers.add_parser('vscode')
    vscode_parser.set_defaults(func=run_vscode)

    args = parser.parse_args()
    args.func(args)
