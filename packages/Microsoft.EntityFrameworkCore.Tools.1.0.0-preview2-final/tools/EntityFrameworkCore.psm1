$ErrorActionPreference = 'Stop'

$EFDefaultParameterValues = @{
    ProjectName = ''
    ContextTypeName = ''
}

#
# Use-DbContext
#

Register-TabExpansion Use-DbContext @{
    Context = { param ($tabExpansionContext) GetContextTypes $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Sets the default DbContext to use.

.DESCRIPTION
    Sets the default DbContext to use.

.PARAMETER Context
    Specifies the DbContext to use.

.PARAMETER Project
    Specifies the project to use. If omitted, the default project is used.

.PARAMETER StartupProject
    Specifies the startup project to use. If omitted, the solution's startup project is used.

.PARAMETER Environment
    Specifies the environment to use. If omitted, "Development" is used.

.LINK
    about_EntityFrameworkCore
#>
function Use-DbContext {
    [CmdletBinding(PositionalBinding = $false)]
    param ([Parameter(Position = 0, Mandatory = $true)] [string] $Context, [string] $Project, [string] $StartupProject, [string] $Environment)

    $dteProject = GetProject $Project
    $dteStartupProject = GetStartupProject $StartupProject $dteProject
    if (IsDotNetProject $dteProject) {
        $contextTypes = GetContextTypes $Project $StartupProject $Environment
        $candidates = $contextTypes | ? { $_ -ilike "*$Context" }
        $exactMatch = $contextTypes | ? { $_ -eq $Context }
        if ($candidates.length -gt 1 -and $exactMatch -is "String") {
            $candidates = $exactMatch
        }

        if ($candidates.length -lt 1) {
            throw "No DbContext named '$Context' was found"
        } elseif ($candidates.length -gt 1 -and !($candidates -is "String")) {
            throw "More than one DbContext named '$Context' was found. Specify which one to use by providing its fully qualified name."
        }

        $contextTypeName=$candidates
    } else {
        $contextTypeName = InvokeOperation $dteStartupProject $Environment $dteProject GetContextType @{ name = $Context }
    }

    $EFDefaultParameterValues.ContextTypeName = $contextTypeName
    $EFDefaultParameterValues.ProjectName = $dteProject.ProjectName
}

#
# Add-Migration
#

Register-TabExpansion Add-Migration @{
    Context = { param ($tabExpansionContext) GetContextTypes $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    Project = { GetProjects }
    StartupProject = { GetProjects }
    # disables tab completion on output dir
    OutputDir = { }
}

<#
.SYNOPSIS
    Adds a new migration.

.DESCRIPTION
    Adds a new migration.

.PARAMETER Name
    Specifies the name of the migration.

.PARAMETER OutputDir
    The directory (and sub-namespace) to use. If omitted, "Migrations" is used. Relative paths are relative to project directory.

.PARAMETER Context
    Specifies the DbContext to use. If omitted, the default DbContext is used.

.PARAMETER Project
    Specifies the project to use. If omitted, the default project is used.

.PARAMETER StartupProject
    Specifies the startup project to use. If omitted, the solution's startup project is used.

.PARAMETER Environment
    Specifies the environment to use. If omitted, "Development" is used.

.LINK
    Remove-Migration
    Update-Database
    about_EntityFrameworkCore
#>
function Add-Migration {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Name,
        [string] $OutputDir,
        [string] $Context,
        [string] $Project,
        [string] $StartupProject,
        [string] $Environment)

    Hint-Upgrade $MyInvocation.MyCommand
    $values = ProcessCommonParameters $StartupProject $Project $Context
    $dteStartupProject = $values.StartupProject
    $dteProject = $values.Project
    $contextTypeName = $values.ContextTypeName

    if (IsDotNetProject $dteProject) {
        $options = ProcessCommonDotnetParameters $Environment $contextTypeName
        if($OutputDir) {
            $options += "--output-dir", (NormalizePath $OutputDir)
        }
        $files = InvokeDotNetEf $dteProject $dteStartupProject -json migrations add $Name @options
        $DTE.ItemOperations.OpenFile($files.MigrationFile) | Out-Null
    }
    else {
        $artifacts = InvokeOperation $dteStartupProject $Environment $dteProject AddMigration @{
            name = $Name
            outputDir = $OutputDir
            contextType = $contextTypeName
        }
        
        $dteProject.ProjectItems.AddFromFile($artifacts.MigrationFile) | Out-Null

        try {
            $dteProject.ProjectItems.AddFromFile($artifacts.MetadataFile) | Out-Null
        } catch {
            # in some SKUs the call to add MigrationFile will automatically add the MetadataFile because it is named ".Designer.cs"
            # this will throw a non fatal error when -OutputDir is outside the main project directory
        }

        $dteProject.ProjectItems.AddFromFile($artifacts.SnapshotFile) | Out-Null
        $DTE.ItemOperations.OpenFile($artifacts.MigrationFile) | Out-Null
        ShowConsole
    }

    Write-Output 'To undo this action, use Remove-Migration.'
}

#
# Update-Database
#

Register-TabExpansion Update-Database @{
    Migration = { param ($tabExpansionContext) GetMigrations $tabExpansionContext.Context $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    Context = { param ($tabExpansionContext) GetContextTypes $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Updates the database to a specified migration.

.DESCRIPTION
    Updates the database to a specified migration.

.PARAMETER Migration
    Specifies the target migration. If '0', all migrations will be reverted. If omitted, all pending migrations will be applied.

.PARAMETER Context
    Specifies the DbContext to use. If omitted, the default DbContext is used.

.PARAMETER Project
    Specifies the project to use. If omitted, the default project is used.

.PARAMETER StartupProject
    Specifies the startup project to use. If omitted, the solution's startup project is used.

.PARAMETER Environment
    Specifies the environment to use. If omitted, "Development" is used.

.LINK
    Script-Migration
    about_EntityFrameworkCore
#>
function Update-Database {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Position = 0)]
        [string] $Migration,
        [string] $Context,
        [string] $Project,
        [string] $StartupProject,
        [string] $Environment)

    Hint-Upgrade $MyInvocation.MyCommand
    $values = ProcessCommonParameters $StartupProject $Project $Context
    $dteStartupProject = $values.StartupProject
    $dteProject = $values.Project
    $contextTypeName = $values.ContextTypeName

    if (IsDotNetProject $dteProject) {
        $options = ProcessCommonDotnetParameters $Environment $contextTypeName
        InvokeDotNetEf $dteProject $dteStartupProject database update $Migration @options | Out-Null
        Write-Output "Done."
    } else {
        if (IsUwpProject $dteProject) {
            throw 'Update-Database should not be used with Universal Windows apps. Instead, call DbContext.Database.Migrate() at runtime.'
        }

        InvokeOperation $dteStartupProject $Environment $dteProject UpdateDatabase @{
            targetMigration = $Migration
            contextType = $contextTypeName
        }
    }
}

#
# Script-Migration
#

Register-TabExpansion Script-Migration @{
    From = { param ($tabExpansionContext) GetMigrations $tabExpansionContext.Context $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    To = { param ($tabExpansionContext) GetMigrations $tabExpansionContext.Context $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    Context = { param ($tabExpansionContext) GetContextTypes $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Generates a SQL script from migrations.

.DESCRIPTION
    Generates a SQL script from migrations.

.PARAMETER From
    Specifies the starting migration. If omitted, '0' (the initial database) is used.

.PARAMETER To
    Specifies the ending migration. If omitted, the last migration is used.

.PARAMETER Idempotent
    Generates an idempotent script that can be used on a database at any migration.

.PARAMETER Context
    Specifies the DbContext to use. If omitted, the default DbContext is used.

.PARAMETER Project
    Specifies the project to use. If omitted, the default project is used.

.PARAMETER StartupProject
    Specifies the startup project to use. If omitted, the solution's startup project is used.

.PARAMETER Environment
    Specifies the environment to use. If omitted, "Development" is used.

.LINK
    Update-Database
    about_EntityFrameworkCore
#>
function Script-Migration {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(ParameterSetName = 'WithoutTo')]
        [Parameter(ParameterSetName = 'WithTo', Mandatory = $true)]
        [string] $From,
        [Parameter(ParameterSetName = 'WithTo', Mandatory = $true)]
        [string] $To,
        [switch] $Idempotent,
        [string] $Context,
        [string] $Project,
        [string] $StartupProject,
        [string] $Environment)

    $values = ProcessCommonParameters $StartupProject $Project $Context
    $dteStartupProject = $values.StartupProject
    $dteProject = $values.Project
    $contextTypeName = $values.ContextTypeName

    $fullPath = GetProperty $dteProject.Properties FullPath
    $intermediatePath = if (IsDotNetProject $dteProject) { "obj\Debug\" }
        else { GetProperty $dteProject.ConfigurationManager.ActiveConfiguration.Properties IntermediatePath }
    $fullIntermediatePath = Join-Path $fullPath $intermediatePath
    $fileName = [IO.Path]::GetRandomFileName()
    $fileName = [IO.Path]::ChangeExtension($fileName, '.sql')
    $scriptFile = Join-Path $fullIntermediatePath $fileName

    if (IsDotNetProject $dteProject) {
        $options = ProcessCommonDotnetParameters $Environment $contextTypeName

        $options += "--output",$scriptFile
        if ($Idempotent) {
            $options += ,"--idempotent"
        }

        InvokeDotNetEf $dteProject $dteStartupProject migrations script $From $To @options | Out-Null

        $DTE.ItemOperations.OpenFile($scriptFile) | Out-Null

    } else {
        $script = InvokeOperation $dteStartupProject $Environment $dteProject ScriptMigration @{
            fromMigration = $From
            toMigration = $To
            idempotent = [bool]$Idempotent
            contextType = $contextTypeName
        }
        try {
            # NOTE: Certain SKUs cannot create new SQL files, including xproj
            $window = $DTE.ItemOperations.NewFile('General\Sql File')
            $textDocument = $window.Document.Object('TextDocument')
            $editPoint = $textDocument.StartPoint.CreateEditPoint()
            $editPoint.Insert($script)
        }
        catch {
            $script | Out-File $scriptFile -Encoding utf8
            $DTE.ItemOperations.OpenFile($scriptFile) | Out-Null
        }
    }

    ShowConsole
}

#
# Remove-Migration
#

Register-TabExpansion Remove-Migration @{
    Context = { param ($tabExpansionContext) GetContextTypes $tabExpansionContext.Project $tabExpansionContext.StartupProject $tabExpansionContext.Environment }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Removes the last migration.

.DESCRIPTION
    Removes the last migration.

.PARAMETER Context
    Specifies the DbContext to use. If omitted, the default DbContext is used.

.PARAMETER Project
    Specifies the project to use. If omitted, the default project is used.

.PARAMETER StartupProject
    Specifies the startup project to use. If omitted, the solution's startup project is used.

.PARAMETER Environment
    Specifies the environment to use. If omitted, "Development" is used.

.PARAMETER Force
    Removes the last migration without checking the database. If the last migration has been applied to the database, you will need to manually reverse the changes it made.

.LINK
    Add-Migration
    about_EntityFrameworkCore
#>
function Remove-Migration {
    [CmdletBinding(PositionalBinding = $false)]
    param ([string] $Context, [string] $Project, [string] $StartupProject, [string] $Environment, [switch] $Force)

    $values = ProcessCommonParameters $StartupProject $Project $Context
    $dteProject = $values.Project
    $contextTypeName = $values.ContextTypeName
    $dteStartupProject = $values.StartupProject
    $forceRemove = $Force -or (IsUwpProject $dteProject)

    if (IsDotNetProject $dteProject) {
        $options = ProcessCommonDotnetParameters $Environment $contextTypeName
        if ($forceRemove) {
            $options += ,"--force"
        }
        InvokeDotNetEf $dteProject $dteStartupProject migrations remove @options | Out-Null
        Write-Output "Done."
    } else {
        $filesToRemove = InvokeOperation $dteStartupProject $Environment $dteProject RemoveMigration @{
            contextType = $contextTypeName
            force = [bool]$forceRemove
        }

        $filesToRemove | %{
            $projectItem = GetProjectItem $dteProject $_
            if ($projectItem) {
                $projectItem.Remove()
            }
        }
    }
}

#
# Scaffold-DbContext
#

Register-TabExpansion Scaffold-DbContext @{
    Provider = { param ($tabExpansionContext) GetProviders $tabExpansionContext.Project }
    Project = { GetProjects }
    StartupProject = { GetProjects }
}

<#
.SYNOPSIS
    Scaffolds a DbContext and entity type classes for a specified database.

.DESCRIPTION
    Scaffolds a DbContext and entity type classes for a specified database.

.PARAMETER Connection
    Specifies the connection string of the database.

.PARAMETER Provider
    Specifies the provider to use. For example, Microsoft.EntityFrameworkCore.SqlServer.

.PARAMETER OutputDir
    Specifies the directory to use to output the classes. If omitted, the top-level project directory is used.

.PARAMETER Context
    Specifies the name of the generated DbContext class.

.PARAMETER Schemas
    Specifies the schemas for which to generate classes.

.PARAMETER Tables
    Specifies the tables for which to generate classes.

.PARAMETER DataAnnotations
    Use DataAnnotation attributes to configure the model where possible. If omitted, the output code will use only the fluent API.

.PARAMETER Force
    Force scaffolding to overwrite existing files. Otherwise, the code will only proceed if no output files would be overwritten.

.PARAMETER Project
    Specifies the project to use. If omitted, the default project is used.

.PARAMETER StartupProject
    Specifies the startup project to use. If omitted, the solution's startup project is used.

.PARAMETER Environment
    Specifies the environment to use. If omitted, "Development" is used.

.LINK
    about_EntityFrameworkCore
#>
function Scaffold-DbContext {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Connection,
        [Parameter(Position = 1, Mandatory =  $true)]
        [string] $Provider,
        [string] $OutputDir,
        [string] $Context,
        [string[]] $Schemas = @(),
        [string[]] $Tables = @(),
        [switch] $DataAnnotations,
        [switch] $Force,
        [string] $Project,
        [string] $StartupProject,
        [string] $Environment)

    $values = ProcessCommonParameters $StartupProject $Project
    $dteStartupProject = $values.StartupProject
    $dteProject = $values.Project

    if (IsDotNetProject $dteProject) {
        $options = ProcessCommonDotnetParameters $Environment $Context
        if ($OutputDir) {
            $options += "--output-dir",(NormalizePath $OutputDir)
        }
        if ($DataAnnotations) {
            $options += ,"--data-annotations"
        }
        if ($Force) {
            $options += ,"--force"
        }
        $options += $Schemas | % { "--schema", $_ }
        $options += $Tables | % { "--table", $_ }

        InvokeDotNetEf $dteProject $dteStartupProject dbcontext scaffold $Connection $Provider @options | Out-Null
    } else {
        $artifacts = InvokeOperation $dteStartupProject $Environment $dteProject ReverseEngineer @{
            connectionString = $Connection
            provider = $Provider
            outputDir = $OutputDir
            dbContextClassName = $Context
            schemaFilters = $Schemas
            tableFilters = $Tables
            useDataAnnotations = [bool]$DataAnnotations
            overwriteFiles = [bool]$Force
        }

        $artifacts | %{ $dteProject.ProjectItems.AddFromFile($_) | Out-Null }
        $DTE.ItemOperations.OpenFile($artifacts[0]) | Out-Null

        ShowConsole
    }
}

#
# Enable-Migrations (Obsolete)
#

function Enable-Migrations {
    # TODO: Link to some docs on the changes to Migrations
    Hint-Upgrade $MyInvocation.MyCommand
    Write-Warning 'Enable-Migrations is obsolete. Use Add-Migration to start using Migrations.'
}

#
# (Private Helpers)
#

function GetProjects {
    $projects = Get-Project -All
    $groups = $projects | group Name

    return $projects | %{
        if ($groups | ? Name -eq $_.Name | ? Count -eq 1) {
            return $_.Name
        }

        return $_.ProjectName
    }
}

function GetContextTypes($projectName, $startupProjectName, $environment) {
    $values = ProcessCommonParameters $startupProjectName $projectName
    $startupProject = $values.StartupProject
    $project = $values.Project

    if (IsDotNetProject $startupProject) {
        $options = ProcessCommonDotnetParameters $environment
        $types = InvokeDotNetEf $startupProject $startupProject -json -skipBuild dbcontext list @options
        return $types | %{ $_.fullName }
    } else {
        $contextTypes = InvokeOperation $startupProject $environment $project GetContextTypes -skipBuild
        return $contextTypes | %{ $_.SafeName }
    }
}

function GetMigrations($contextTypeName, $projectName, $startupProjectName, $environment) {
    $values = ProcessCommonParameters $startupProjectName $projectName $contextTypeName
    $startupProject = $values.StartupProject
    $project = $values.Project
    $contextTypeName = $values.ContextTypeName

    if (IsDotNetProject $startupProject) {
        $options = ProcessCommonDotnetParameters $environment $contextTypeName
        $migrations = InvokeDotNetEf $startupProject $startupProject -json -skipBuild migrations list @options
        return $migrations | %{ $_.safeName }
    }
    else {
        $migrations = InvokeOperation $startupProject $environment $project GetMigrations @{ contextTypeName = $contextTypeName } -skipBuild
        return $migrations | %{ $_.SafeName }
    }
}

function ProcessCommonParameters($startupProjectName, $projectName, $contextTypeName) {
    $project = GetProject $projectName

    if (!$contextTypeName -and $project.ProjectName -eq $EFDefaultParameterValues.ProjectName) {
        $contextTypeName = $EFDefaultParameterValues.ContextTypeName
    }

    $startupProject = GetStartupProject $startupProjectName $project

    return @{
        Project = $project
        ContextTypeName = $contextTypeName
        StartupProject = $startupProject
    }
}

function NormalizePath($path) {
    try {
        $pathInfo = Resolve-Path -LiteralPath $path
        return $pathInfo.Path.TrimEnd([IO.Path]::DirectorySeparatorChar)
    } 
    catch {
        # when directories don't exist yet
        return $path.TrimEnd([IO.Path]::DirectorySeparatorChar)
    }
}

function ProcessCommonDotnetParameters($environment, $contextTypeName) {
    $options=@()
    if ($environment) {
        $options += "--environment",$environment
    }
    if ($contextTypeName) {
        $options += "--context",$contextTypeName
    }
    return $options
}

function IsDotNetProject($project) {
    $project.FileName -like "*.xproj" -or $project.Kind -eq "{8BB2217D-0F2D-49D1-97BC-3654ED321F3B}"
}

function IsUwpProject($project) {
    $targetFrameworkMoniker = GetProperty $project.Properties TargetFrameworkMoniker
    $frameworkName = New-Object System.Runtime.Versioning.FrameworkName $targetFrameworkMoniker
    return $frameworkName.Identifier -eq '.NETCore'
}

function GetProject($projectName) {
    if ($projectName) {
        return Get-Project $projectName
    }

    return Get-Project
}

function ShowConsole {
    $componentModel = Get-VSComponentModel
    $powerConsoleWindow = $componentModel.GetService([NuGetConsole.IPowerConsoleWindow])
    $powerConsoleWindow.Show()
}

function InvokeDotNetEf($dteProject, $dteStartupProject, [switch] $json, [switch] $skipBuild) {

    if (!(IsDotNetProject $dteProject) -or !(IsDotNetProject $dteStartupProject)) {
        Write-Warning "This command may fail unless both the targeted project and startup project are ASP.NET Core or .NET Core projects."
    }

    if ($env:DOTNET_INSTALL_DIR) {
        $dotnet = Join-Path $env:DOTNET_INSTALL_DIR dotnet.exe
    } else {
        $cmd = Get-Command dotnet -ErrorAction Ignore # searches $env:PATH
        if ($cmd) {
            $dotnet = $cmd.Path
        }
    }

    if (!(Test-Path $dotnet)) {
        throw "Could not find .NET Core CLI (dotnet.exe) in the PATH or DOTNET_INSTALL_DIR environment variables. .NET Core CLI is required to execute EF commands on this project type."
    }

    Write-Debug "Using $dotnet"
    $targetFullPath = GetProperty $dteProject.Properties FullPath
    $targetProjectJson = Join-Path $targetFullPath project.json
    try {
        Write-Debug "Reading $targetProjectJson"
        $projectDef = Get-Content $targetProjectJson -Raw | ConvertFrom-Json
    } catch {
        Write-Verbose $_.Exception.Message
        throw "Invalid JSON file in $targetProjectJson"
    }
    if ($projectDef.tools) {
        $t=$projectDef.tools | Get-Member Microsoft.EntityFrameworkCore.Tools
    }
    if (!$t) {
        $projectName = $dteProject.ProjectName
        throw "Cannot execute this command because 'Microsoft.EntityFrameworkCore.Tools' is not installed in project '$projectName'. Add 'Microsoft.EntityFrameworkCore.Tools' to the 'tools' section in project.json. See http://go.microsoft.com/fwlink/?LinkId=798221 for more details."
    }

    $arguments=@()

    $startupProjectPath =  GetProperty $dteStartupProject.Properties FullPath
    $arguments += "--startup-project", (NormalizePath $startupProjectPath)

    $startupProjectName =  $dteStartupProject.ProjectName
    Write-Verbose "Using startup project '$startupProjectName'"

    $config = $dteStartupProject.ConfigurationManager.ActiveConfiguration.ConfigurationName
    $arguments += "--configuration", $config
    Write-Debug "Using configuration $config"

    $buildBasePath = GetProperty $dteStartupProject.ConfigurationManager.ActiveConfiguration.Properties OutputPath
    $arguments += "--build-base-path", (NormalizePath $buildBasePath)
    Write-Debug "Using build base path $buildBasePath"
    
    if ($skipBuild) {
        $arguments += ,"--no-build"
    }

    $arguments += $args

    if ($json) {
        $arguments += ,"--json"
    }

    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        $arguments += ,"--verbose"
    }

    $arguments = $arguments | ? { $_ } | % { "'$($_ -replace "'", "''" )'" }

    $output = $null

    $command = "ef $($arguments -join ' ')"
    try {
        Write-Verbose "Working directory: $targetFullPath"
        Push-Location $targetFullPath
        $ErrorActionPreference='SilentlyContinue'
        Write-Verbose "Executing command: dotnet $command"
        # TODO don't use invoke-expression.
        # This will require running dotnet-build as a separate command because build
        # warnings still appear in stderr
        $stdout = Invoke-Expression "& '$dotnet' $command" -ErrorVariable stderr
        $exit = $LASTEXITCODE
        $stdout | Out-String | Write-Verbose
        Write-Debug "Finish executing command with code $exit"
        if ($exit -ne 0) {
            if (!($stderr)) {
                if (!($stdout)) {
                    # This should never happen
                    throw "An unexpected error occurred."
                }
                # most often occurs when Microsoft.EntityFrameworkCore.Tools didn't install
                throw $stdout
            }
            throw $stderr
        }

        if ($json) {
            Write-Debug "Parsing json output"
            $startLine = $stdout.IndexOf("//BEGIN") + 1
            $endLine = $stdout.IndexOf("//END") - 1
            $output = $stdout[$startLine..$endLine] -join [Environment]::NewLine | ConvertFrom-Json
        } else {
            $output = $stdout -join [Environment]::NewLine
        }
    }
    finally {
        $ErrorActionPreference='Stop'
        Pop-Location
    }
    return $output
}

function InvokeOperation($startupProject, $environment, $project, $operation, $arguments = @{}, [switch] $skipBuild) {
    $startupProjectName = $startupProject.ProjectName

    Write-Verbose "Using startup project '$startupProjectName'."

    $projectName = $project.ProjectName

    Write-Verbose "Using project '$projectName'"

    if (IsDotNetProject $startupProject) {
        throw "This command cannot use '$startupProjectName' as the startup project because '$projectName' is not an ASP.NET Core or .NET Core project"
    }

    $package = Get-Package -ProjectName $startupProjectName | ? Id -eq Microsoft.EntityFrameworkCore.Tools
    if (!($package)) {
        throw "Cannot execute this command because Microsoft.EntityFrameworkCore.Tools is not installed in the startup project '$startupProjectName'."
    }

    if (!$skipBuild) {

        if (IsUwpProject $startupProject) {
            $config = $startupProject.ConfigurationManager.ActiveConfiguration.ConfigurationName
            $configProperties = $startupProject.ConfigurationManager.ActiveConfiguration.Properties
            $isNative = (GetProperty $configProperties ProjectN.UseDotNetNativeToolchain) -eq 'True'

            if ($isNative) {
                throw "Cannot run in '$config' mode because 'Compile with the .NET Native tool chain' is enabled. Disable this setting or use a different configuration and try again."
            }
        }

        Write-Verbose 'Build started...'

        # TODO: Only build required project. Don't use BuildProject, you can't specify platform
        $solutionBuild = $DTE.Solution.SolutionBuild
        $solutionBuild.Build($true)
        if ($solutionBuild.LastBuildInfo) {
            throw "Build failed."
        }

        Write-Verbose 'Build succeeded.'
    }

    if (![Type]::GetType('Microsoft.EntityFrameworkCore.Design.OperationResultHandler')) {
        Add-Type -Path (Join-Path $PSScriptRoot OperationHandlers.cs) -CompilerParameters (
            New-Object CodeDom.Compiler.CompilerParameters -Property @{
                CompilerOptions = '/d:NET451'
            })
    }

    $logHandler = New-Object Microsoft.EntityFrameworkCore.Design.OperationLogHandler @(
        { param ($message) Write-Error $message }
        { param ($message) Write-Warning $message }
        { param ($message) Write-Host $message }
        { param ($message) Write-Verbose $message }
        { param ($message) Write-Debug $message }
    )

    $properties = $project.Properties
    $fullPath = GetProperty $properties FullPath

    $startupOutputPath = GetProperty $startupProject.ConfigurationManager.ActiveConfiguration.Properties OutputPath
    $startupProperties = $startupProject.Properties
    $startupFullPath = GetProperty $startupProperties FullPath
    $appBasePath = Join-Path $startupFullPath $startupOutputPath

    $webConfig = GetProjectItem $startupProject 'Web.Config'
    $appConfig = GetProjectItem $startupProject 'App.Config'

    if ($webConfig) {
        $configurationFile = GetProperty $webConfig.Properties FullPath
        $dataDirectory = Join-Path $startupFullPath 'App_Data'
    }
    elseif ($appConfig) {
        $configurationFile = GetProperty $appConfig.Properties FullPath
    }

    Write-Verbose "Using application base '$appBasePath'."

    $info = New-Object AppDomainSetup -Property @{
        ApplicationBase = $appBasePath
        ShadowCopyFiles = 'true'
    }

    if ($configurationFile) {
        Write-Verbose "Using application configuration '$configurationFile'"
        $info.ConfigurationFile = $configurationFile
    }
    else {
        Write-Verbose 'No configuration file found.'
    }

    $domain = [AppDomain]::CreateDomain('EntityFrameworkCoreDesignDomain', $null, $info)
    if ($dataDirectory) {
        Write-Verbose "Using data directory '$dataDirectory'"
        $domain.SetData('DataDirectory', $dataDirectory)
    }
    try {
        $commandsAssembly = 'Microsoft.EntityFrameworkCore.Tools'
        $commandsAssemblyFile = Join-Path $appBasePath "$commandsAssembly.dll"
        if (!(Test-Path $commandsAssemblyFile)) {
            Copy-Item "$PSScriptRoot/../lib/net451/$commandsAssembly.dll" $appBasePath
            $removeCommandsAssembly = $True
        }
        $operationExecutorTypeName = 'Microsoft.EntityFrameworkCore.Design.OperationExecutor'
        $targetAssemblyName = GetProperty $properties AssemblyName
        $startupAssemblyName = GetProperty $startupProperties AssemblyName
        $rootNamespace = GetProperty $properties RootNamespace
        $currentDirectory = [IO.Directory]::GetCurrentDirectory()

        $executor = $domain.CreateInstanceAndUnwrap(
            $commandsAssembly,
            $operationExecutorTypeName,
            $false,
            0,
            $null,
            @(
                [MarshalByRefObject]$logHandler,
                @{
                    startupTargetName = $startupAssemblyName
                    targetName = $targetAssemblyName
                    environment = $environment
                    projectDir = $fullPath
                    contentRootPath = $startupFullPath
                    rootNamespace = $rootNamespace
                }
            ),
            $null,
            $null)

        $resultHandler = New-Object Microsoft.EntityFrameworkCore.Design.OperationResultHandler

        Write-Verbose "Using current directory '$appBasePath'."

        [IO.Directory]::SetCurrentDirectory($appBasePath)
        try {
            $domain.CreateInstance(
                $commandsAssembly,
                "$operationExecutorTypeName+$operation",
                $false,
                0,
                $null,
                ($executor, [MarshalByRefObject]$resultHandler, $arguments),
                $null,
                $null) | Out-Null
        }
        finally {
            [IO.Directory]::SetCurrentDirectory($currentDirectory)
        }
    }
    finally {
        [AppDomain]::Unload($domain)
        if ($removeCommandsAssembly) {
            Remove-Item $commandsAssemblyFile
        }
    }

    if ($resultHandler.ErrorType) {
        if ($resultHandler.ErrorType -eq 'Microsoft.EntityFrameworkCore.Design.OperationException') {
            Write-Verbose $resultHandler.ErrorStackTrace
        }
        else {
            Write-Host $resultHandler.ErrorStackTrace
        }

        throw $resultHandler.ErrorMessage
    }
    if ($resultHandler.HasResult) {
        return $resultHandler.Result
    }
}

function GetProperty($properties, $propertyName) {
    try {
        return $properties.Item($propertyName).Value
    } catch {
        return $null
    }
}

function GetProjectItem($project, $path) {
    $fullPath = GetProperty $project.Properties FullPath

    if (Split-Path $path -IsAbsolute) {
        $path = $path.Substring($fullPath.Length)
    }

    $itemDirectory = (Split-Path $path -Parent)

    $projectItems = $project.ProjectItems
    if ($itemDirectory) {
        $directories = $itemDirectory.Split('\')
        $directories | %{
            $projectItems = $projectItems.Item($_).ProjectItems
        }
    }

    $itemName = Split-Path $path -Leaf

    try {
        return $projectItems.Item($itemName)
    }
    catch [Exception] {
    }

    return $null
}

function GetStartUpProject($name, $fallbackProject) {
    if ($name) {
        return Get-Project $name
    }

    $startupProjectPaths = $DTE.Solution.SolutionBuild.StartupProjects
    if ($startupProjectPaths) {
        if ($startupProjectPaths.Length -eq 1) {
            $startupProjectPath = $startupProjectPaths[0]
            if (!(Split-Path -IsAbsolute $startupProjectPath)) {
                $solutionPath = Split-Path (GetProperty $DTE.Solution.Properties Path)
                $startupProjectPath = Join-Path $solutionPath $startupProjectPath -Resolve
            }

            $startupProject = GetSolutionProjects | ?{
                try {
                    $fullName = $_.FullName
                }
                catch [NotImplementedException] {
                    return $false
                }

                if ($fullName -and $fullName.EndsWith('\')) {
                    $fullName = $fullName.Substring(0, $fullName.Length - 1)
                }

                return $fullName -eq $startupProjectPath
            }
            if ($startupProject) {
                return $startupProject
            }

            Write-Warning "Unable to resolve startup project '$startupProjectPath'."
        }
        else {
            Write-Verbose 'More than one startup project found.'
        }
    }
    else {
        Write-Verbose 'No startup project found.'
    }

    return $fallbackProject
}

function GetSolutionProjects() {
    $projects = New-Object System.Collections.Stack

    $DTE.Solution.Projects | %{
        $projects.Push($_)
    }

    while ($projects.Count -ne 0) {
        $project = $projects.Pop();

        # NOTE: This line is similar to doing a "yield return" in C#
        $project

        if ($project.ProjectItems) {
            $project.ProjectItems | ?{ $_.SubProject } | %{
                $projects.Push($_.SubProject)
            }
        }
    }
}

function GetProviders($projectName) {
    if (!($projectName)) {
        $projectName = (Get-Project).ProjectName
    }

    return Get-Package -ProjectName $projectName | select -ExpandProperty Id
}

function Hint-Upgrade ($name) {
    if (Get-Module | ? Name -eq EntityFramework) {
        Write-Warning "Both Entity Framework Core and Entity Framework 6.x commands are installed. The Entity Framework Core version is executing. You can fully qualify the command to select which one to execute, 'EntityFramework\$name' for EF6.x and 'EntityFrameworkCore\$name' for EF Core."
    }
}
# SIG # Begin signature block
# MIIkCgYJKoZIhvcNAQcCoIIj+zCCI/cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBtlfYsTtvndhfP
# b2xVEIizWaPA6SGgmYIBVLldV6rcVqCCDZIwggYQMIID+KADAgECAhMzAAAAZEeE
# lIbbQRk4AAAAAABkMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTUxMDI4MjAzMTQ2WhcNMTcwMTI4MjAzMTQ2WjCBgzEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjENMAsGA1UECxMETU9Q
# UjEeMBwGA1UEAxMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMIIBIjANBgkqhkiG9w0B
# AQEFAAOCAQ8AMIIBCgKCAQEAky7a2OY+mNkbD2RfTahYTRQ793qE/DwRMTrvicJK
# LUGlSF3dEp7vq2YoNNV9KlV7TE2K8sDxstNSFYu2swi4i1AL3X/7agmg3GcExPHf
# vHUYIEC+eCyZVt3u9S7dPkL5Wh8wrgEUirCCtVGg4m1l/vcYCo0wbU06p8XzNi3u
# XyygkgCxHEziy/f/JCV/14/A3ZduzrIXtsccRKckyn6B5uYxuRbZXT7RaO6+zUjQ
# hiyu3A4hwcCKw+4bk1kT9sY7gHIYiFP7q78wPqB3vVKIv3rY6LCTraEbjNR+phBQ
# EL7hyBxk+ocu+8RHZhbAhHs2r1+6hURsAg8t4LAOG6I+JQIDAQABo4IBfzCCAXsw
# HwYDVR0lBBgwFgYIKwYBBQUHAwMGCisGAQQBgjdMCAEwHQYDVR0OBBYEFFhWcQTw
# vbsz9YNozOeARvdXr9IiMFEGA1UdEQRKMEikRjBEMQ0wCwYDVQQLEwRNT1BSMTMw
# MQYDVQQFEyozMTY0Mis0OWU4YzNmMy0yMzU5LTQ3ZjYtYTNiZS02YzhjNDc1MWM0
# YjYwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1ApUwVAYDVR0fBE0wSzBJ
# oEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljQ29k
# U2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEFBQcBAQRVMFMwUQYIKwYB
# BQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2VydHMvTWlj
# Q29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNVHRMBAf8EAjAAMA0GCSqG
# SIb3DQEBCwUAA4ICAQCI4gxkQx3dXK6MO4UktZ1A1r1mrFtXNdn06DrARZkQTdu0
# kOTLdlGBCfCzk0309RLkvUgnFKpvLddrg9TGp3n80yUbRsp2AogyrlBU+gP5ggHF
# i7NjGEpj5bH+FDsMw9PygLg8JelgsvBVudw1SgUt625nY7w1vrwk+cDd58TvAyJQ
# FAW1zJ+0ySgB9lu2vwg0NKetOyL7dxe3KoRLaztUcqXoYW5CkI+Mv3m8HOeqlhyf
# FTYxPB5YXyQJPKQJYh8zC9b90JXLT7raM7mQ94ygDuFmlaiZ+QSUR3XVupdEngrm
# ZgUB5jX13M+Pl2Vv7PPFU3xlo3Uhj1wtupNC81epoxGhJ0tRuLdEajD/dCZ0xIni
# esRXCKSC4HCL3BMnSwVXtIoj/QFymFYwD5+sAZuvRSgkKyD1rDA7MPcEI2i/Bh5O
# MAo9App4sR0Gp049oSkXNhvRi/au7QG6NJBTSBbNBGJG8Qp+5QThKoQUk8mj0ugr
# 4yWRsA9JTbmqVw7u9suB5OKYBMUN4hL/yI+aFVsE/KJInvnxSzXJ1YHka45ADYMK
# AMl+fLdIqm3nx6rIN0RkoDAbvTAAXGehUCsIod049A1T3IJyUJXt3OsTd3WabhIB
# XICYfxMg10naaWcyUePgW3+VwP0XLKu4O1+8ZeGyaDSi33GnzmmyYacX3BTqMDCC
# B3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29m
# dCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDExMB4XDTExMDcwODIwNTkw
# OVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAx
# MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKvw+nIQHC6t2G6qghBN
# NLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL8DjCmQawyDnVARQxQtOJ
# DXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/XllnKYBoF6WZ26DJSJhIv
# 56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5kNXimoGMPLdNAk/jj3gcN
# 1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJXtjt7UORg9l7snuGG9k+
# sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4ftKdgCz1TlaRITUlwzlu
# ZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgotswnKDglmDlKNs98sZKu
# HCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0XpbL9Uj43BdD1FGd7P4AOG8
# rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy5yTfv0aZxe/CHFfbg43s
# TUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9Z4DmimJ4X7IvhNdXnFy/
# dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4IFgsE11glZo+TzOE2rCI
# F96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQBgkrBgEEAYI3FQEEAwIB
# ADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUwGQYJKwYBBAGCNxQCBAwe
# CgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0j
# BBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0fBFMwUTBPoE2gS4ZJaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2Vy
# QXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcBAQRSMFAwTgYIKwYBBQUH
# MAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2Vy
# QXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGXMIGUMIGRBgkrBgEEAYI3
# LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lv
# cHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBh
# AGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG
# 9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFjkplCln3SeQyQwWVfLiw+
# +MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtGUFXYDJJ80hpLHPM8QotS
# 0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32mkHSDjfTLJgJGKsKKELuk
# qQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr3vw70L01724lruWvJ+3Q
# 3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYKwsatruWy2dsViFFFWDgy
# cScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6CPxNNZgvAs0314Y9/HG8V
# fUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX0O5dY0HjWwechz4GdwbR
# BrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADWoUa9WfOXpQlLSBCZgB/Q
# ACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9rt0uX4ut1eBrs6jeZeRhL
# /9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGdVk5Pv4BXIqF4ETIheu9B
# CrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9bW1qyVJzEw16UM0xghXO
# MIIVygIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExAhMzAAAA
# ZEeElIbbQRk4AAAAAABkMA0GCWCGSAFlAwQCAQUAoIG6MBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqG
# SIb3DQEJBDEiBCDeC8ByCZnf4VaeHORakm0tYB8YsvLz6ne0eT1ecBkvqDBOBgor
# BgEEAYI3AgEMMUAwPqAkgCIATQBpAGMAcgBvAHMAbwBmAHQAIABBAFMAUAAuAE4A
# RQBUoRaAFGh0dHA6Ly93d3cuYXNwLm5ldC8gMA0GCSqGSIb3DQEBAQUABIIBACH5
# m7NEjnjruombGFre2SoEC3XAVOMbXyrC8sVZDFN1bWbrw3sz/ElD4RfrIOy2khBf
# ZwHpdTe7xh4RG5RFWVob+cYQC76esf2tUAfPXVWZSRNYq7MBJaRWa0utvWOyFS8m
# ZWqgxOKBfiM1wMUGDaRdb6b9n4YQoudHhrXUWynU444oogAgHyTlcu71NbJJmL6d
# 8J62HxvAy7cPVVL3C1WhVdL0JrOvbRuzD7RJFSQ+fijo5saHx55NRyEtosMIqwNV
# /0j22js/2NvfvfLR+JVo20i3QsJ1I7RIi3ub3FNxO/Jx5LHvjo4vm3p/Gm8ZdVR9
# JvDGaYwQEb7KHubwCQmhghNMMIITSAYKKwYBBAGCNwMDATGCEzgwghM0BgkqhkiG
# 9w0BBwKgghMlMIITIQIBAzEPMA0GCWCGSAFlAwQCAQUAMIIBPAYLKoZIhvcNAQkQ
# AQSgggErBIIBJzCCASMCAQEGCisGAQQBhFkKAwEwMTANBglghkgBZQMEAgEFAAQg
# wTAL8KhPLdeSMTLC3h4YyQVPw2tEatIwU0322OaRuhMCBldphX495hgSMjAxNjA2
# MjIxNjE0NDMuOTdaMAcCAQGAAgH0oIG5pIG2MIGzMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMQ0wCwYDVQQLEwRNT1BSMScwJQYDVQQLEx5uQ2lw
# aGVyIERTRSBFU046N0QyRS0zNzgyLUIwRjcxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2Wggg7QMIIGcTCCBFmgAwIBAgIKYQmBKgAAAAAAAjAN
# BgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9y
# aXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcNMjUwNzAxMjE0NjU1WjB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0VBDVpQoAgoX77XxoSyxfxcPlYcJ2
# tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEwRA/xYIiEVEMM1024OAizQt2TrNZz
# MFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQedGFnkV+BVLHPk0ySwcSmXdFhE24o
# xhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKxXf13Hz3wV3WsvYpCTUBR0Q+cBj5n
# f/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4GkbaICDXoeByw6ZnNPOcvRLqn9Nxk
# vaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEAAaOCAeYwggHiMBAGCSsGAQQBgjcV
# AQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7fEYbxTNoWoVtVTAZBgkrBgEEAYI3
# FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAf
# BgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNS
# b29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0Nl
# ckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0gAQH/BIGVMIGSMIGPBgkrBgEEAYI3
# LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9QS0kv
# ZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBs
# AF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcN
# AQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOhIW+z66bM9TG+zwXiqf76V20ZMLPC
# xWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS+7lTjMz0YBKKdsxAQEGb3FwX/1z5
# Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlKkVIArzgPF/UveYFl2am1a+THzvbK
# egBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon/VWvL/625Y4zu2JfmttXQOnxzplm
# kIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOiPPp/fZZqkHimbdLhnPkd/DjYlPTG
# pQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/fmNZJQ96LjlXdqJxqgaKD4kWumGn
# Ecua2A5HmoDF0M2n0O99g/DhO3EJ3110mCIIYdqwUB5vvfHhAN/nMQekkzr3ZUd4
# 6PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0cs0d9LiFAR6A+xuJKlQ5slvayA1V
# mXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7aKLixqduWsqdCosnPGUFN4Ib5Kpqj
# EWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQcdeh0sVV42neV8HR3jDA/czmTfsN
# v11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+NR4Iuto229Nfj950iEkSMIIE2jCC
# A8KgAwIBAgITMwAAAJsh15YBk1eLpAAAAAAAmzANBgkqhkiG9w0BAQsFADB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0xNjA0MjcxNzA2MjBaFw0xNzA3
# MjcxNzA2MjBaMIGzMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMScwJQYDVQQLEx5uQ2lwaGVyIERTRSBFU046N0QyRS0z
# NzgyLUIwRjcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC27664ibg6nlWOKRaz8buY
# peuYSDwW6Fvu1JFRkI56i/o9ssqzHrq6+bXzp2g8ciuPbi/4SiXnw3uxlde2+gvi
# CcZRPApflwD3xpVyxDUvvawcgya4gsPFQ7Dr2HtwtsPf3f6y4HE3Q44bg0Y0jxAW
# 5Pd1bUJvJc2EjtRl6KB6rp2MDABHyr1khLWOjOzw3iKmn5PXQu8GPjjBkiAjjRej
# mpkjFs93TvTlwpkEIgw3L60ucF3okYjN2soPwkQXyIiRSNPQ5ASewhFgnS1iKwPW
# nGDIDXNAZESBWImbAd3UHEJB+nI5hjSb6viBEb83UinBRyOWOt0M9QW7aDEX1Sg/
# AgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQU1v9QCRB8wjREZ656a22pdbhif6kwHwYD
# VR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZF
# aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGlt
# U3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcw
# AoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQ
# Q0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEF
# BQcDCDANBgkqhkiG9w0BAQsFAAOCAQEApGszlkqdxpoX9EWf80MEsAA7HEm15YYw
# 2FmC5jIpUje+XhO5K4+1Pluv3AuIv1KQb21uPZ50/Dx5SfKT/G991+ztzeE1Aib0
# dYqdlPLupTYmqTInVWThCEwTBvowXFeZjLIgbIuFkBsTioC0/cXaDf6xumm13+oc
# IR3FISNyX4JJCT2DZWpD8okcImlj+DNpdhZ0ekSs7X9bb/HffF/EmsWqfrbXQT5b
# LCGHHAU6bFDkPX9ks7Uq3bIEfoLWSS+WbrGXb3aymBjjR/aYQlR9g9gzBWIHz831
# Qw0ci1Vy9w/0WQYcAROvA5NosgTJuUoWtr9C2WR5ZhYMFrOyolM6jaGCA3kwggJh
# AgEBMIHjoYG5pIG2MIGzMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMQ0wCwYDVQQLEwRNT1BSMScwJQYDVQQLEx5uQ2lwaGVyIERTRSBFU046N0Qy
# RS0zNzgyLUIwRjcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZp
# Y2WiJQoBATAJBgUrDgMCGgUAAxUANdTiX7yMkGnOyfaboQijWNe1f+yggcIwgb+k
# gbwwgbkxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xDTALBgNV
# BAsTBE1PUFIxJzAlBgNVBAsTHm5DaXBoZXIgTlRTIEVTTjo1N0Y2LUMxRTAtNTU0
# QzErMCkGA1UEAxMiTWljcm9zb2Z0IFRpbWUgU291cmNlIE1hc3RlciBDbG9jazAN
# BgkqhkiG9w0BAQUFAAIFANsUWh0wIhgPMjAxNjA2MjIwMDI4MTNaGA8yMDE2MDYy
# MzAwMjgxM1owdzA9BgorBgEEAYRZCgQBMS8wLTAKAgUA2xRaHQIBADAKAgEAAgIF
# 3QIB/zAHAgEAAgIYPzAKAgUA2xWrnQIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgor
# BgEEAYRZCgMBoAowCAIBAAIDFuNgoQowCAIBAAIDB6EgMA0GCSqGSIb3DQEBBQUA
# A4IBAQCSQaZeS6qGvN/IfXb0mCgxYCY9FQ3wgw167OEjSNvhccFxd3nAq6EaIYr3
# WeG3LAy7ZlHI+8TZSY7DddpI9/3NmE0pjLERL9+deS9F++jmIx3OsYGch7KAxYAn
# 5ARa16op5Yc9lw9XmwbRT2vDzw1lqcDuVsMQYGcrHaUEP5PKwle6ocrScKNWwA5C
# orxotgm6MwUolZGZcs0faikYlXaewumzda4JnGixUr+2+O+gzAicummCd2UdgW62
# jPqPA2zQE8v3fNgXlL9JdiV1C956hJAaBxbQmU3mn6cyYk3kmHnmvVtVcfpMi7zP
# C4qFF/WqpyYnqR3dpYe3Kn0mmW0bMYIC9TCCAvECAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAACbIdeWAZNXi6QAAAAAAJswDQYJYIZIAWUD
# BAIBBQCgggEyMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgul4hjZdquECV8DvlWI4ySjY8jc7bodUQpq4agUk7aGAwgeIGCyqGSIb3
# DQEJEAIMMYHSMIHPMIHMMIGxBBQ11OJfvIyQac7J9puhCKNY17V/7DCBmDCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAAmyHXlgGTV4ukAAAA
# AACbMBYEFLW9+CSnd0izDfGlQ1tD3ekxuot8MA0GCSqGSIb3DQEBCwUABIIBADPN
# fgBqSiVTlNlSJoJMIgkeGopGiJB3JI22RCC6Cfd25mKjsL1GLoJqPmrFPLHvXnuH
# NxwvRct/nw8J5Z1WGPaEvBxRQyMZ/EL6JhTSMys5V/VI6yRw9ofaFVGvuodVWGm0
# iHByCj9hC/oN55r+PHaD6QxY9x0Ng1vZ+TRjRbWddrHRGPRi/FBWiayBCJZWWqzZ
# N288zNkLnShb0JOPQsVRW61DzX9CwlxtmWAglPbq37S4IKsb7IoVkBcyiRgY10Vj
# +BcsI+t88lyYvu9Y82O3Mx9hJLXoY/tNvVWCr26riS3gh41aXz8td36Ret41Guan
# R0y4WQZo53BMeoratn8=
# SIG # End signature block
