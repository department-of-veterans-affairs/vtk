import { Command, flags as cliFlags } from "@oclif/command";
import opn from "opn";
import chalk from "chalk";
import { rootUrl, jenkinsFlags } from "../../lib/jenkins";
import { currentRepo, currentBranch } from "../../lib/git";

export class CiViewCommand extends Command {
  static description = "View the status of a job in CI.";

  static flags = {
    repo: jenkinsFlags.repo,
    branch: jenkinsFlags.branch,
    build: jenkinsFlags.build
  };

  async run() {
    const { flags } = this.parse(CiViewCommand);
    flags.repo = flags.repo || (await currentRepo());
    flags.branch = flags.branch || (await currentBranch());

    if (!flags.repo) {
      this.error(
        "No git repository found. Either change your current working directory to a git repository or specify one with --repo."
      );
    }
    if (!flags.branch) {
      this.error(
        "No git branch found. Either change your current working directory to a git repository or specify a branch with --branch."
      );
    }

    // lastBuild doesn't work for opening blue ocean, unfortunately, so if the
    // build number isn't an actual number, open the overview page
    if (isNaN(+flags.build)) {
      const url = `${rootUrl}/job/testing/job/${flags.repo}/job/${
        flags.branch
      }`;
      this.log("No build number specified; opening branch overview page.");
      this.log(chalk.dim(url));
      opn(url);
      this.exit(0);
    }

    const url = `${rootUrl}/blue/organizations/jenkins/testing%2F${
      flags.repo
    }/detail/${flags.branch}/${flags.build}/pipeline`;
    this.log(chalk.dim(url));
    opn(url);
  }
}
