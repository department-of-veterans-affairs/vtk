# VSP Toolkit (`vtk`)

The purpose of this gem is to allow VFS engineers to quickly begin developing on the platform. It does this by providing a command line interface that allows the use of simple commands and parameters to do everything from setting up a development environment to building out a directory structure and creating necessary files for separating code into its own module.

*The following assumes you have Ruby 2.6.6 or higher installed.*

## Installation

Install it yourself as:

    $ gem install vtk

## Usage

### Modules

Teams developing for vets-api should create their code as a module. This allows for the separation and easy identification of different projects. To scaffold a directory structure for your module, first cd into the vets-api directory, then enter the command below, substituting the name of your module for *<module name>*. This will build out a directory structure and create necessary files in the `modules/` directory.

    $ vtk module add <module name>
