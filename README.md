# Developer Toolkit

The purpose of this gem is to allow engineers to quickly begin developing on VA.gov. It does this by providing a command line interface that allows the use of simple commands and parameters to do everything from setting up a development environment to building out a directory structure and creating necessary files for separating code into its own module.

*The following assumes you have Ruby 2.6.6 or higher installed*

## Installation

Install it yourself as:

    $ gem install vtk
    
To update to the latest version:

    $ gem update vtk

## Usage

### Modules

Teams developing for vets-api should create their code as a module. This allows for the separation and easy identification of different projects. To scaffold a directory structure for your module, first cd into the vets-api directory, then enter the command below, substituting the name of your module for `<module name>`. This will build out a directory structure and create necessary files in the `modules/` directory.

    $ vtk module add <module name>
	
To add additional functionality to your module, the commands listed below are available for use. These commands can build out common functionality needed when working with a module and will be created within the given module space. When creating a new module component for a module space that does not currently exist, users will be prompted with the choice to create the module directory structure. As above, first cd into the vets-api directory, then enter the command below, substituting the name of your module for `<module name>`. You can specify the name of the module component by including `-n <component name>` after the module name. If you do not specify a module component name then the component will have the same name as the module.
	
    $ vtk module controller <module name> -n <component name>
    $ vtk module model <module name> -n <component name>
    $ vtk module serializer <module name> -n <component name>
    $ vtk module service <module name> -n <component name>
    
This above command runs a custom rails generator. For more information see the [module generator documentation](https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/generators/module/USAGE)

### SOCKS

Handles connecting to VA network via SOCKS.

```
$ vtk socks on
----> Connecting...
----> Connected to SOCKS.
```

To disconnect, run:

```
$ vtk socks off
----> Disconnected from SOCKS.
```
    
### Help

For helpful information about commands and subcommands run the following:

    $ vtk -h
    $ vtk module -h
    $ vtk socks -h

### Docker

If using the vtk gem in Docker, you may first need to run the following commands to avoid any errors:

	$ make docker-clean
	$ make build
	$ make bash
	
### Contributing
1. Clone the repo
2. Create your feature branch (git checkout -b my-new-feature)
3. Run the tests (bundle exec rake)
4. Commit your changes 
5. Push to the branch (git push origin my-new-feature)
6. Create new Pull Request

### Releasing
1. Merge in your approved pull requests
2. Update the version to be whatever it should (in lib/vtk/version.rb) be and commit
   - The version bump could also be part of your PR
3. ``` bundle exec rake release ``` 
   - This will tag the release and publish to RubyGems
4. Update the changelog — (```github_changelog_generator -u department-of-veterans-affairs -p vtk```)
