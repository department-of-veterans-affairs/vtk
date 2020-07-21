import {Command, flags} from '@oclif/command'
import * as inquirer from 'inquirer'
import * as fuzzy from 'fuzzy'
import * as _ from 'lodash'

export default class Products extends Command {
  static description = 'manage products on VSP'

  static flags = {
    help: flags.help({char: 'h'}),
    websitePath: flags.string({env: 'VAGOVDIR'})
  }

  static args = [{name: 'file'}]

  async run() {
    const {args, flags} = this.parse(Products)
    const products = ["0993-edu-benefits","0994-edu-benefits","0996-higher-level-review","10203-edu-benefits","1990-edu-benefits","1990e-edu-benefits","1990n-edu-benefits","1995-edu-benefits","526EZ-all-claims","526EZ-claims-increase","5490-edu-benefits","5495-edu-benefits","686-dependent-status","account","auth","bdd","beta-enrollment","burials","caregivers","chapter31-vre","chapter36-vre","claims-status","connected-accounts","dashboard","dependents-view-dependents","disability-my-rated-disabilities","discharge-upgrade-instructions","facilities","feedback-tool","gi","hca","hearing-aid-batteries-and-accessories","letters","login-page","my-health-account-validation","new-686","pensions","post-911-gib-status","pre-need","profile-2","profile-360","proxy-rewrite","public-outreach-materials","search","static-pages","terms-and-conditions","vaos","verify","veteran-id-card","veteran-representative","yellow-ribbon"]
    let product = flags.product;
    // TODO: Get the values from $WEBSITE_PATH/script/app-list.sh
    // TODO: Move that logic into this toolkit?
    inquirer.registerPrompt('autocomplete', require('inquirer-autocomplete-prompt'));
    function searchProducts(answers, input) {
      input = input || '';
      return new Promise(function(resolve) {
        setTimeout(function() {
          var fuzzyResult = fuzzy.filter(input, products)
          resolve(
            fuzzyResult.map(function(el) {
              return el.original
            })
          )
        }, _.random(30, 500));
      })
    }

    let responses: any = await inquirer.prompt([
      {
        name: 'product',
        message: 'choose a product',
        type: 'autocomplete',
        source: searchProducts,
        pageSize: 16
      }
    ])
    product = responses.product
    this.log(`You chose: ${product}`)
    this.log('list options here...')
  }
}
