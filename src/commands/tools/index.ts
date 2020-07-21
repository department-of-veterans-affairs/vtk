import {Command, flags} from '@oclif/command'
import fs from 'fs'
import * as inquirer from 'inquirer'
import * as YAML from 'yaml'

export default class Tools extends Command {
  static description = 'manage tools on VSP'

  static flags = {
    help: flags.help({char: 'h'}),
  }

  static args = [{name: 'file'}]

  async run() {
    const {args, flags} = this.parse(Tools)
    let tools = ['Grafana', 'Sentry'];

    let responses: any = await inquirer.prompt([
      {
        name: 'tool',
        message: 'choose a tool',
        type: 'list',
        choices: tools
      }
    ])
    let tool = responses.tool
    console.log(tool)
  }
}
