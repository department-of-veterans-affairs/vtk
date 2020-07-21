import {Command, flags} from '@oclif/command'
import * as inquirer from 'inquirer'
import * as colors from 'colors'

export default class Doctor extends Command {
  static description = 'run basic configuration validations for your development environment'

  static flags = {
    help: flags.help({char: 'h'}),
    // flag with no value (-f, --force)
    force: flags.boolean({char: 'f'}),
    verbose: flags.boolean({char: 'v', description: 'increased verbosity'}),
  }

  static args = [{}]

  async run() {
    const colors = require('colors');

    colors.setTheme({
      info: 'bgGreen',
      help: 'cyan',
      warn: 'yellow',
      success: 'bgBlue',
      error: 'red',
    });

    const {args, flags} = this.parse(Doctor)

    const checks = ['SOCKS access', 'SSH configuration is correct', 'Keys are encrypted', 'Keys verify the user', 'SSH Keys in session', 'Docker version', 'AWS Profile loaded']
    // let responses: any = await inquirer.prompt([{name: 'checkup', message: 'Pick one', choices: checks, type: 'list'}])
    // let check = responses.check
    const docString = 'Paging the Doctor 💊'.help
    this.log('')
    this.log(docString)
    this.log('')
    for (let c of checks) {

      this.log(`-- ${c}${'.'.repeat(60 - c.length)}✅`)
    }
  }
}
