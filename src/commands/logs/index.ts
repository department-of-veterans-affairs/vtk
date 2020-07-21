import { Command, flags } from "@oclif/command";
import * as inquirer from "inquirer";
import cli from "cli-ux";

export default class Logs extends Command {
  static description = "manage and view product or service logs";

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
    let env = flags.env;
    if (!env) {
      let responses: any = await inquirer.prompt([
        {
          name: "environment",
          message: "choose an environment",
          type: "list",
          choices: [
            { name: "dev" },
            { name: "staging" },
            { name: "production" },
          ],
        },
      ]);
      env = responses.environment;
    }
    this.log(`📜 Pulling logs from: ${env}`);
  }
}
