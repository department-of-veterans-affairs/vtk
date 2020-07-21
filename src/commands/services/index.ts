import {Command, flags} from '@oclif/command'
import fs from 'fs'
import * as inquirer from 'inquirer'
import * as YAML from 'yaml'

export default class Services extends Command {
  static description = 'manage services on VSP'

  static flags = {
    help: flags.help({char: 'h'}),
    // flag with a value (-n, --name=VALUE)
    name: flags.string({char: 'n', description: 'name to print'}),
    // flag with no value (-f, --force)
    force: flags.boolean({char: 'f'}),
  }

  static args = [{name: 'file'}]

  async run() {
    const {args, flags} = this.parse(Services)
    let service = flags.service
    let serviceNames = [];
    if (!service) {
      try {
        const services = YAML.parse(fs.readFileSync(process.cwd() + '/src/commands/services.yml', 'utf8'))
        // serviceNames = Object.keys(services.services)
        for (let s of Object.keys(services.services)) {
          let formattedName = services.services[s].prettyName + ' - ' + services.services[s].description
          serviceNames.push(formattedName) // (services[s])
          // console.log(services.services[s].description)
        }
      } catch (e) {
        console.log(e)
      }
      let responses: any = await inquirer.prompt([
        {
          name: 'service',
          message: 'choose a service',
          type: 'list',
          choices: serviceNames
        }
      ])
      service = responses.service
    }

    const name = flags.name ?? 'world'

    if (args.file && flags.force) {
      this.log(`you input --force and --file: ${args.file}`)
    }
  }
}
