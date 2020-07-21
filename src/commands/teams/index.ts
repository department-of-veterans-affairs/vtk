import {Command, flags} from '@oclif/command'

export default class Teams extends Command {
  static description = 'manage teams building on VSP'

  static flags = {
    help: flags.help({char: 'h'}),
    // flag with a value (-n, --name=VALUE)
    name: flags.string({char: 'n', description: 'name to print'}),
    // flag with no value (-f, --force)
    force: flags.boolean({char: 'f'}),
  }

  static args = [{name: 'file'}]

  async run() {
    const {args, flags} = this.parse(Teams)

    const name = flags.name ?? 'world'
    this.log(`hello ${name} from /home/kf/src/department-of-veterans-affairs/vsp-toolkit/src/commands/teams.ts`)
    if (args.file && flags.force) {
      this.log(`you input --force and --file: ${args.file}`)
    }
  }
}
