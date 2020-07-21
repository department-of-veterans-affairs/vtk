import Help from '@oclif/plugin-help';
import {Command,Topic} from '@oclif/config';

export default class CustomHelp extends Help {
  protected showRootHelp() {
    let rootTopics = this.sortedTopics
    let rootCommands = this.sortedCommands


    let ansiArt = `
                                ▓  VSP TOOLKIT
      ▓▓▓░    ▓▓▓▓ ▓▓▓▓▓        ▓  -----------
      ▒▓▓▓    ▓▓▓ ░▓▓▒▓▓        ▓  Version: 0.0.1a
       ▒▓▓▓  ▓▓▓▓  ▓▓ ▓▓        ▓  License: MIT
       ░▓▓▓ ░▓▓▒ ▒▓▓▒ ▓▓▓▒      ▓  Maintainer: Keifer Furzland <keifer.furzland@va.gov>
        ▓▓▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓      ▓
         ▓▓▓▓▓▓ ▓▓▓▓   ▓▓▓▓     ▓
         ░▓▓▓▓  ▓▓▓     ▓▓▓     ▓
                                ▓
                                ▓
    `
    console.log('----------------------------------------------------------------------------------------')
    console.log(ansiArt)
    console.log('----------------------------------------------------------------------------------------')


    console.log(this.formatRoot())
    console.log('')

    if (!this.opts.all) {
      rootTopics = rootTopics.filter(t => !t.name.includes(':'))
      rootCommands = rootCommands.filter(c => !c.id.includes(':'))
    }

    if (rootTopics.length > 0) {
      console.log(this.formatTopics(rootTopics))
      console.log('')
    }

    if (rootCommands.length > 0) {
      console.log(this.formatCommands(rootCommands))
      console.log('')
    }
  }
}
