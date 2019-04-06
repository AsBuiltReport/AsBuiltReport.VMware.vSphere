# Contributing
Your input is welcome! Contributing to this project is as easy as:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Creating a new report

When contributing to this repository, please first discuss the change you wish to make via [issue](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues), or [direct message](https://powershell.slack.com/messages/D3MU9DP8S) in the [PowerShell Slack](https://powershell.slack.com) channel before making a change.

## Develop with Github
This project uses Github to host code, to track issues and feature requests, as well as accept pull requests.

## We use [Github Flow](https://guides.github.com/introduction/flow/index.html)
Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests.

### Creating quality pull requests
A good quality pull request will have the following characteristics:

- It will be a complete piece of work that adds value in some way.
- It will have a title that reflects the work within, and a summary that helps to understand the context of the change.
- There will be well written commit messages, with well crafted commits that tell the story of the development of this work.
- Ideally it will be small and easy to understand. Single commit PRs are usually easy to submit, review, and merge.
- The code contained within will meet the best practices set by the team wherever possible.

### Submitting pull requests
1. Fork this repository (AsBuiltReport.VMware.vSphere), or if you are developing a report, fork the specific report repository. The example below uses the main AsBuiltReport.VMware.vSphere repository in the command examples.
2. Add `https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere.git` as a remote named `upstream`.
    - `git remote add upstream https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere.git`
3. Create your feature branch from `dev`.
4. Work on your feature.
    - Update `CHANGELOG.md` in the repository you have worked in with add / remove / change information
    - Update `README.md` in the repository you have worked in with any new information, such as features, instructions, parameters and/or examples
5. Squash commits into one or two succinct commits.
    - `git rebase -i HEAD~n` # n being the number of previous commits to rebase
6. Ensure that your branch is up to date with `upstream/dev`.
    - `git checkout <branch>`
    - `git fetch upstream`
    - `git rebase upstream/dev`
7. Push branch to your fork.
    - `git push --force`
8. Open a Pull Request against the `dev` branch of this repository. We have Pull Requests templates in all repositories for this project. Please follow the template with each Pull Request

Pull requests will be reviewed as soon as possible.

## Any contributions you make will be under the MIT Software License
In short, when you submit code changes, your submissions are understood to be under the same [MIT License](http://choosealicense.com/licenses/mit/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report Issues and Bugs
[GitHub issues](https://github.com/AsBuiltReport/AsBuiltReport.VMware.vSphere/issues) is used to track issues and bugs. Report a bug by opening a new issue, it's that easy!

## Submit bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

## Use a Consistent Coding Style
Code contributors should follow the [PowerShell Guidelines](https://github.com/PoshCode/PowerShellPracticeAndStyle) wherever possible to ensure scripts are consistent in style.

Use [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) to check code quality against PowerShell Best Practices.

### DO
- Use [PascalCasing](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/capitalization-conventions) for all public member, type, and namespace names consisting of multiple words.
- Use custom label headers within tables, where required, to make easily readable labels.
- Favour readability over brevity
- Use PSCustomObjects to store data that will be exported to a PScribo table. This helps with readability
- Try to perform all safe commands (Get-*, Get API call, etc) at the start of a report script (after functions) so it can easily be seen what data is being collected
- Use comments written in English, but don't overdo it. Comments should serve to your reasoning and decision-making, not attempt to explain what a command does
- Maintain a change log as per [these guidelines](https://keepachangelog.com/en/1.0.0/). The change log should be named CHANGELOG.md

### DON'T
- Do not include code within report script to install or import PowerShell modules.

## Creating a New Report Repository

If you are interested in creating a new report for the AsBuiltReport project that does not yet exist, the information in this section details the process to create a new repository that will contain the new report.

1. Ask a project owner to create a new repository for your new report under the organisation on GitHub, following the naming standard `AsBuiltReport.<Vendor>.<Product>`. In these intructions we will use an example by using HPE's Nimble Storage product, so the repository will be named `AsBuiltReport.HPE.NimbleStorage`. The project owner will create a new repository with a master branch, a dev branch, both containing a license file and nothing else in the repository. When the repository is created, make a fork of the repository and clone it to your machine using git.

2. Open the newly created report folder and create a Powershell `.psm1` file, using the same name as the root folder for the file name. In this example, the .psm1 file will be called `AsBuiltReport.HPE.NimbleStorage.psm1`. Enter the code below in to the .psm1 file (you can also copy this file from another AsBuiltReport Repository and rename it if you prefer).

```Powershell
# Get public function definition files and dot source them
$Public = @(Get-ChildItem -Path $PSScriptRoot\Src\Public\*.ps1)

foreach ($Module in $Public) {
    try {
        . $Module.FullName
    } catch {
        Write-Error -Message "Failed to import function $($Module.FullName): $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
```

3. Copy the .github folder from another AsbuiltReport repository in to the root of the new report folder. This file contains the default Pull Request template for the project as well as the Issue Templates for the project. These should be standard across all of the repositories for the AsBuiltReport project.

4. Copy the .vscode folder from another AsBuiltReport repository in to the root of the new report folder. This contains the Visual Studio code style that is used for consistency across all of the repositories in the AsBuiltReport project.

5. Create the following folder structure under the root folder:

```
───Src
    └───Public
```

6. In the `Public` folder, create a .ps1 file named `Invoke-<ReportName>.ps1`. For example, `Invoke-AsBuiltReport.HPE.NimbleStorage.ps1`. This powershell script file will contain at least one function, with the function name being the same as the ps1 file, so in thie example the function would be named `Invoke-AsBuiltReport.HPE.NimbleStorage`

7. In the project root folder, create a JSON file, named <ReportName>.json. For example, `AsBuiltReport.HPE.NimbleStorage.json`. Copy the json configuration below in to the file as a starting point.
```json
{
    "Report": {
        "Name": "<Vendor Name> As Built Report",
        "Version": "1.0",
        "Status": "Released"
    },
    "Options": {
    },
    "Section": {
    },
    "InfoLevel": {
        "_comment_": "0 = Disabled, 1 = Summary, 2 = Informative, 3 = Detailed, 4 = Adv Detailed, 5 = Comprehensive"
    },
    "HealthCheck": {
    }
}
```

8. We now need to create a Powershell module manifest file. Open a PowerShell console and change your directory to the root folder of the new report. Change the data in the example below for the `$manifest` variable to show the accurate details for your new report. Run the code below in the powershell session to create a new Powershell manifest file, which should result in a `psd1` file being created in the root folder for the new report:

```Powershell
$manifest = @{
    Path              = '.\AsBuiltReport.HPE.NimbleStorage.psd1'
    RootModule        = 'AsBuiltReport.HPE.NimbleStorage.psm1' 
    Author            = 'Matthew Allford'
	Description		  = 'A PowerShell module to generate an as built report on the configuration of HPE Nimble Storage arrays.'
    FunctionsToExport = 'Invoke-AsBuiltReport.HPE.NimbleStorage'
    RequiredModules = @{
        'AsBuiltReport.Core'
    }
}
New-ModuleManifest @manifest
```

9. Create a `README.md` file in the root folder. Ensure the README contains useful information before your first pull request!

10. That's the main shell for a new report repository completed! Make a Pull Request from your fork to the dev branch of the main repository for the initial commit with the main framework for the new report

## License
By contributing, you agree that your contributions will be licensed under the MIT License.
