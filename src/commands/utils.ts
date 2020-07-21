import {Command, flags} from '@oclif/command'

export default class Utils extends Command {
  static description = 'global utilities and misc. tools'

  static flags = {
    help: flags.help({char: 'h'}),
    // flag with a value (-n, --name=VALUE)
    name: flags.string({char: 'n', description: 'name to print'}),
    // flag with no value (-f, --force)
    force: flags.boolean({char: 'f'}),
  }

  static args = [{name: 'file'}]

  async run() {
    const {args, flags} = this.parse(Utils)

    // const name = flags.name ?? 'world'
    // this.log(`hello ${name} from /home/kf/src/department-of-veterans-affairs/vsp-toolkit/src/commands/utils.ts`)
    // if (args.file && flags.force) {
    //   this.log(`you input --force and --file: ${args.file}`)
    // }

    const { exec } = require('child_process');
    this.log('You require a listing of EC2 instances, eh?');
    exec("ruby /home/kf/src/department-of-veterans-affairs/devops/utilities/aws_hosts.rb", (error, stdout, stderr) => {
      if (error) {
        console.log(`error: ${error.message}`);
        return
      }
      if (stderr) {
        console.log(`stderr: ${stderr}`);
        return;
      }
      console.log(`${stdout}`);
      this.log('How \'bout them apples?! 🍎 🍎');
    });
  }
}
