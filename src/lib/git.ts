import path from "path";
import simpleGit from "simple-git";
const git = simpleGit();

export async function currentRepo(): Promise<string | undefined> {
  if (!(await git.checkIsRepo())) return undefined;
  const repoPath = await git.revparse(["--show-toplevel"]);
  return path.basename(repoPath);
}

export async function currentBranch(): Promise<string | undefined> {
  if (!(await git.checkIsRepo())) return undefined;
  return (await git.branch()).current;
}
