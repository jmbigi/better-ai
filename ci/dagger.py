#!/usr/bin/env python3
"""Pipeline de CI local con Dagger para better-ai.

Requiere: pip install dagger-io
Uso: dagger run python ci/dagger.py
"""
import sys
import dagger


async def main():
    async with dagger.Connection(dagger.Config(log_output=sys.stderr)):
        client = dagger.Client()
        src = client.host.directory(".")

        result = await (
            client.container(platform="linux/amd64")
            .from_("ubuntu:24.04")
            .with_mounted_directory("/src", src)
            .with_workdir("/src")
            .with_exec(["apt-get", "update"])
            .with_exec(
                [
                    "apt-get",
                    "install",
                    "-y",
                    "--no-install-recommends",
                    "bash",
                    "git",
                    "locales",
                    "make",
                    "python3",
                    "shellcheck",
                    "uuid-runtime",
                ]
            )
            .with_exec(["make", "check"])
            .stdout()
        )

    print(result)


if __name__ == "__main__":
    dagger.Any(main)
