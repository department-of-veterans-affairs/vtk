import { flags } from "@oclif/command";

export const rootUrl = "http://jenkins.vfs.va.gov";

// Async because it has to wait for git to get the information about the current repo and branch
export const jenkinsFlags = {
  repo: flags.string({
    char: "R",
    description:
      "Name of the repository. Defaults to the repository of the current working directory."
  }),
  branch: flags.string({
    char: "f",
    description: "Name of the branch. Defaults to the current git branch."
  }),
  build: flags.string({
    char: "b",
    description: "Specify the build number. Defaults to lastBuild",
    default: "lastBuild"
  })
};
