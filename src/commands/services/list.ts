import { Command, flags } from "@oclif/command";
import * as inquirer from "inquirer";
import cli from "cli-ux";

export default class Logs extends Command {
  static description = "list all available logs";

  static flags = {
    help: flags.help({ char: "h" }),
    // flag with a value (-e, --env=VALUE)
    env: flags.string({ char: "e", description: "target environment" }),
    // flag with no value (-f, --force)
    force: flags.boolean({ char: "f" }),
  };

  static args = [{ name: "file" }];

  async run() {
    const { args, flags } = this.parse(Logs);
    this.log("These logs exist!");
  }
}
