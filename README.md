# VSP Toolkit (`vtk`)

The purpose of this gem is to allow VFS engineers to quickly begin developing on the platform. It does this by providing a command line interface that allows the use of simple commands and parameters to do everything from setting up a development environment to building out a directory structure and creating necessary files for separating code into its own module.

*The following assumes you have Ruby 2.6.6 or higher and Rails ~> 6.0.2 installed*

## Installation

Install it yourself as:

    $ gem install vtk

## Usage

### Modules

Teams developing for vets-api should create their code as a module. This allows for the separation and easy identification of different projects. To scaffold a directory structure for your module, first cd into the vets-api directory, then enter the command below, substituting the name of your module for `<module name>`. This will build out a directory structure and create necessary files in the `modules/` directory.

    $ vtk module add <module name>
	
To add additional functionality to your module, the commands listed below are available for use. These commands can build out common functionality needed when working with a module and will be created within the given module space. When creating a new module component for a module space that does not currently exist, users will be prompted with the choice to create the module directory structure. As above, first cd into the vets-api directory, then enter the command below, substituting the name of your module for *<module name>*
	
	$ vtk module controller <module name>
	$ vtk module model <module name>
	$ vtk module serializer <module name>
	$ vtk module service <module name>
    
This above command runs a custom rails generator. For more information see the [module generator documentation](https://github.com/department-of-veterans-affairs/vets-api/blob/master/lib/generators/module/USAGE)
    
### Help

For helpful information about commands and subcommands run the following:

    $ vtk -h
